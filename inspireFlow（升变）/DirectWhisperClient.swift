import Foundation

// MARK: - Direct Whisper STT Client

/// Calls `vaibhavs10/incredibly-fast-whisper` on Replicate via the Hack Club AI proxy.
///
/// Uses base64-encoded data URIs so no external file hosting is needed.
/// The proxy expects a `version` (model hash) — we fetch it once and cache for the session.
actor DirectWhisperClient {
    static let shared = DirectWhisperClient()

    private let baseURL = URL(string: "https://ai.hackclub.com/proxy/v1/replicate")!
    private let apiKey: String = ViaimCredentials.whisperKey
    private let modelOwner = "vaibhavs10"
    private let modelName = "incredibly-fast-whisper"

    private var cachedVersion: String?

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 180
        return URLSession(configuration: config)
    }()

    // MARK: - Public

    /// Transcribe an audio file. Returns the recognised text.
    func transcribe(audioFileURL: URL, language: String? = nil) async throws -> String {
        let audioData = try Data(contentsOf: audioFileURL)
        return try await transcribe(audioData: audioData, mimeType: mimeTypeForFile(audioFileURL), language: language)
    }

    /// Transcribe raw audio data with a given MIME type.
    func transcribe(audioData: Data, mimeType: String = "audio/mp4", language: String? = nil) async throws -> String {
        let version = try await resolveVersion()
        let dataURI = dataURI(audioData, mimeType: mimeType)

        var input: [String: Any] = [
            "audio": dataURI,
            "task": "transcribe"
        ]
        if let language {
            input["language"] = language
        }

        let body: [String: Any] = [
            "version": version,
            "input": input
        ]

        var request = URLRequest(url: baseURL.appendingPathComponent("predictions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("wait", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw DirectWhisperError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            if let envelope = try? JSONDecoder().decode(DirectWhisperErrorBody.self, from: data) {
                throw DirectWhisperError.server(http.statusCode, envelope.detail ?? envelope.title ?? "未知错误")
            }
            throw DirectWhisperError.server(http.statusCode, "HTTP \(http.statusCode)")
        }

        let result = try JSONDecoder().decode(DirectWhisperPrediction.self, from: data)

        guard result.status == "succeeded" else {
            let message = result.error ?? "预测状态: \(result.status)"
            throw DirectWhisperError.predictionFailed(message)
        }

        guard let text = result.output?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            throw DirectWhisperError.emptyTranscription
        }

        return text
    }

    // MARK: - Internal

    private func resolveVersion() async throws -> String {
        if let cached = cachedVersion { return cached }

        let url = baseURL
            .appendingPathComponent("models")
            .appendingPathComponent(modelOwner)
            .appendingPathComponent(modelName)

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DirectWhisperError.modelNotFound
        }

        let model = try JSONDecoder().decode(DirectWhisperModel.self, from: data)
        cachedVersion = model.latestVersion.id
        return model.latestVersion.id
    }

    private func dataURI(_ data: Data, mimeType: String) -> String {
        let base64 = data.base64EncodedString()
        return "data:\(mimeType);base64,\(base64)"
    }

    private func mimeTypeForFile(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "wav": return "audio/wav"
        case "mp3": return "audio/mpeg"
        case "m4a": return "audio/mp4"
        case "aac": return "audio/aac"
        default: return "audio/mp4"
        }
    }
}

// MARK: - Response types

private struct DirectWhisperModel: Decodable {
    struct Version: Decodable {
        let id: String
    }
    let latestVersion: Version

    enum CodingKeys: String, CodingKey {
        case latestVersion = "latest_version"
    }
}

private struct DirectWhisperPrediction: Decodable {
    let status: String
    let output: DirectWhisperOutput?
    let error: String?
}

private struct DirectWhisperOutput: Decodable {
    let text: String?
}

private struct DirectWhisperErrorBody: Decodable {
    let detail: String?
    let title: String?
}

// MARK: - Errors

enum DirectWhisperError: Error, LocalizedError {
    case modelNotFound
    case invalidResponse
    case server(Int, String)
    case predictionFailed(String)
    case emptyTranscription

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "无法获取 Whisper 模型信息，请稍后重试。"
        case .invalidResponse:
            return "Replicate 返回了无法识别的响应。"
        case .server(let code, let message):
            return "Replicate 服务错误（\(code)）：\(message)"
        case .predictionFailed(let message):
            return "Whisper 转写失败：\(message)"
        case .emptyTranscription:
            return "Whisper 未返回转写文本，录音可能太短或没有语音内容。"
        }
    }
}
