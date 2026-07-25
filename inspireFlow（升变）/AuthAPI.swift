import Foundation

// MARK: - DTOs (see docs/HANDOFF_USERSYS.MD in inspire-flow-backend)

struct UserPublicDTO: Decodable {
    let id: UUID
    let nickname: String
    let avatarURL: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, nickname
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SessionCreatedDTO: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresAt: Date
    let user: UserPublicDTO

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresAt = "expires_at"
        case user
    }
}

private struct UserCreateRequest: Encodable {
    let nickname: String
    let password: String
}

private struct SessionCreateRequest: Encodable {
    let nickname: String
    let password: String
}

// MARK: - Auth API

/// Thin wrapper around `/api/v1/users` and `/api/v1/sessions`.
///
/// Registration does not create a session by itself (per the backend
/// contract), so callers that want a signed-in user after registering must
/// follow up with `login`.
enum AuthAPI {
    static func register(nickname: String, password: String) async throws -> UserPublicDTO {
        let body = try BackendJSON.encoder.encode(UserCreateRequest(nickname: nickname, password: password))
        return try await APIClient.shared.send("users", method: "POST", body: body)
    }

    static func login(nickname: String, password: String) async throws -> SessionCreatedDTO {
        let body = try BackendJSON.encoder.encode(SessionCreateRequest(nickname: nickname, password: password))
        return try await APIClient.shared.send("sessions", method: "POST", body: body)
    }

    static func demoLogin() async throws -> SessionCreatedDTO {
        try await APIClient.shared.send("sessions/demo", method: "POST")
    }

    static func logout(accessToken: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.send(
            "sessions/current",
            method: "DELETE",
            accessToken: accessToken
        )
    }

    static func currentUser(accessToken: String) async throws -> UserPublicDTO {
        try await APIClient.shared.send("users/me", accessToken: accessToken)
    }
}
