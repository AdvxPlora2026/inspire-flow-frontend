import Foundation
import Security

// MARK: - Configuration

/// Base URL for the `inspire-flow-backend` FastAPI service.
///
/// Production traffic prefers HTTPS and falls back to the backend origin
/// when the public domain is unavailable.
enum BackendConfig {
    static let baseURL = URL(string: "https://platform.advx.uk")!
    static let fallbackBaseURLs = [URL(string: "http://116.62.42.177:8080")!]
    static let apiPrefix = "api/v1"
}

// MARK: - JSON coding

enum BackendJSON {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = fractionalFormatter.date(from: string) { return date }
            if let date = plainFormatter.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected an RFC 3339 date string, got \(string)"
            )
        }
        return decoder
    }()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(fractionalFormatter.string(from: date))
        }
        return encoder
    }()

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plainFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

/// Placeholder decodable target for requests whose success response has no body (e.g. `204 No Content`).
struct EmptyResponse: Decodable {}

// MARK: - Errors

struct APIErrorEnvelope: Decodable {
    struct Detail: Decodable {
        let code: String
        let message: String
        let details: [ErrorDetail]?
    }

    struct ErrorDetail: Decodable {
        let location: [String]?
        let message: String
        let type: String?
    }

    let error: Detail
}

enum APIClientError: Error, LocalizedError {
    case transport(Error)
    case invalidResponse
    case server(status: Int, code: String, message: String)
    case decoding(Error)
    case unauthorized

    /// The HTTP status code, if known.
    var statusCode: Int? {
        switch self {
        case .server(let status, _, _): return status
        case .unauthorized: return 401
        default: return nil
        }
    }

    /// The backend `error.code` string, if known.
    var code: String? {
        switch self {
        case .server(_, let code, _): return code
        case .unauthorized: return "invalid_session"
        default: return nil
        }
    }

    var errorDescription: String? {
        switch self {
        case .transport(let error):
            return error.localizedDescription
        case .invalidResponse:
            return "服务器返回了无法识别的响应。"
        case .server(_, _, let message):
            return message
        case .decoding:
            return "无法解析服务器返回的数据。"
        case .unauthorized:
            return "登录状态已失效，请重新登录。"
        }
    }
}

// MARK: - Keychain-backed token storage

/// Persists the backend bearer token in the Keychain rather than `UserDefaults`,
/// since it grants access to the signed-in user's account.
enum KeychainTokenStore {
    struct StoredToken: Codable {
        let accessToken: String
        let expiresAt: Date
        let userID: UUID
        let nickname: String
    }

    private static let service = "com.inspireflow.backend.session"
    private static let account = "accessToken"

    static func save(_ token: StoredToken) {
        guard let data = try? BackendJSON.encoder.encode(token) else { return }
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(baseQuery as CFDictionary)

        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func load() -> StoredToken? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? BackendJSON.decoder.decode(StoredToken.self, from: data)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - HTTP client

actor APIClient {
    static let shared = APIClient()

    private let baseURLs: [URL]
    private let session: URLSession

    init(
        baseURL: URL = BackendConfig.baseURL,
        fallbackBaseURLs: [URL] = BackendConfig.fallbackBaseURLs,
        session: URLSession = .shared
    ) {
        self.baseURLs = [baseURL] + fallbackBaseURLs
        self.session = session
    }

    private func endpointURL(for path: String, baseURL: URL) -> URL {
        baseURL
            .appendingPathComponent(BackendConfig.apiPrefix)
            .appendingPathComponent(path)
    }

    private func shouldUseFallback(_ response: HTTPURLResponse) -> Bool {
        response.statusCode == 403 && response.mimeType == "text/html"
    }

    /// Sends a request and decodes a JSON response body.
    func send<Response: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Data? = nil,
        accessToken: String? = nil
    ) async throws -> Response {
        var lastTransportError: Error?

        for (index, baseURL) in baseURLs.enumerated() {
            var request = URLRequest(url: endpointURL(for: path, baseURL: baseURL))
            request.httpMethod = method
            if body != nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            if let accessToken {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }
            request.httpBody = body

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                lastTransportError = error
                continue
            }

            guard let http = response as? HTTPURLResponse else {
                if index < baseURLs.count - 1 { continue }
                throw APIClientError.invalidResponse
            }
            if shouldUseFallback(http), index < baseURLs.count - 1 { continue }
            return try decodeResponse(data: data, response: http)
        }

        if let lastTransportError {
            throw APIClientError.transport(lastTransportError)
        }
        throw APIClientError.invalidResponse
    }

    private func decodeResponse<Response: Decodable>(
        data: Data,
        response http: HTTPURLResponse
    ) throws -> Response {
        guard (200..<300).contains(http.statusCode) else {
            if let envelope = try? BackendJSON.decoder.decode(APIErrorEnvelope.self, from: data) {
                if http.statusCode == 401 {
                    throw APIClientError.unauthorized
                }
                throw APIClientError.server(status: http.statusCode, code: envelope.error.code, message: envelope.error.message)
            }
            throw APIClientError.server(
                status: http.statusCode,
                code: "unknown_error",
                message: "请求失败（状态码 \(http.statusCode)）。"
            )
        }

        if Response.self == EmptyResponse.self {
            // 204/empty-body success responses have nothing to decode.
            return EmptyResponse() as! Response // swiftlint:disable:this force_cast
        }

        if data.isEmpty {
            // Some endpoints return 200 with an empty body (e.g. PUT link).
            guard let empty = EmptyResponse() as? Response else {
                throw APIClientError.decoding(
                    DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Expected empty body"))
                )
            }
            return empty
        }

        do {
            return try BackendJSON.decoder.decode(Response.self, from: data)
        } catch {
            throw APIClientError.decoding(error)
        }
    }

    /// Sends a `multipart/form-data` request (used for transcription uploads).
    func upload<Response: Decodable>(
        _ path: String,
        fieldName: String = "file",
        fileName: String,
        mimeType: String,
        fileData: Data,
        formFields: [String: String] = [:],
        accessToken: String? = nil
    ) async throws -> Response {
        let boundary = UUID().uuidString

        var bodyData = Data()
        for (key, value) in formFields {
            bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
            bodyData.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            bodyData.append("\(value)\r\n".data(using: .utf8)!)
        }
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        bodyData.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        bodyData.append(fileData)
        bodyData.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var lastTransportError: Error?
        for (index, baseURL) in baseURLs.enumerated() {
            var urlRequest = URLRequest(url: endpointURL(for: path, baseURL: baseURL))
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            if let accessToken {
                urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }
            urlRequest.httpBody = bodyData

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: urlRequest)
            } catch {
                lastTransportError = error
                continue
            }

            guard let http = response as? HTTPURLResponse else {
                if index < baseURLs.count - 1 { continue }
                throw APIClientError.invalidResponse
            }
            if shouldUseFallback(http), index < baseURLs.count - 1 { continue }
            return try decodeResponse(data: data, response: http)
        }

        if let lastTransportError {
            throw APIClientError.transport(lastTransportError)
        }
        throw APIClientError.invalidResponse
    }
}
