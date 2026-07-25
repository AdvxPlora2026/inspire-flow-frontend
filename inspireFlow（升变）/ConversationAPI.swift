import Foundation

// MARK: - DTOs

struct ConversationPublicDTO: Decodable {
    let id: UUID
    let userID: UUID
    let title: String?
    let archived: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case title, archived
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ConversationPageDTO: Decodable {
    let items: [ConversationPublicDTO]
    let total: Int
    let limit: Int
    let offset: Int
}

struct ConversationMessagePublicDTO: Decodable {
    let id: UUID
    let turnID: UUID
    let sequence: Int
    let role: String
    let content: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case turnID = "turn_id"
        case sequence, role, content
        case createdAt = "created_at"
    }
}

struct ConversationMessagePageDTO: Decodable {
    let items: [ConversationMessagePublicDTO]
    let nextCursor: Int?
    let limit: Int

    enum CodingKeys: String, CodingKey {
        case items, limit
        case nextCursor = "next_cursor"
    }
}

struct AgentTurnPublicDTO: Decodable {
    let turnID: UUID
    let userMessage: ConversationMessagePublicDTO
    let assistantMessage: ConversationMessagePublicDTO
    let memoryUpdates: [MemoryDTO]?
    let memoryExtractionStatus: String

    enum CodingKeys: String, CodingKey {
        case turnID = "turn_id"
        case userMessage = "user_message"
        case assistantMessage = "assistant_message"
        case memoryUpdates = "memory_updates"
        case memoryExtractionStatus = "memory_extraction_status"
    }
}

struct MemoryDTO: Decodable {
    let id: UUID
    let category: String
    let content: String
    let status: String
    let isSensitive: Bool
    let isPinned: Bool

    enum CodingKeys: String, CodingKey {
        case id, category, content, status
        case isSensitive = "is_sensitive"
        case isPinned = "is_pinned"
    }
}

private struct ConversationCreateRequest: Encodable {
    let title: String?
}

private struct ConversationMessageCreateRequest: Encodable {
    let content: String
}

private struct ConversationUpdateRequest: Encodable {
    var title: String? = nil
    var archived: Bool? = nil

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(archived, forKey: .archived)
    }

    enum CodingKeys: String, CodingKey { case title, archived }
}

// MARK: - Agent Conversation API

enum ConversationAPI {
    static func create(title: String? = nil, accessToken: String) async throws -> ConversationPublicDTO {
        let body = try BackendJSON.encoder.encode(ConversationCreateRequest(title: title))
        return try await APIClient.shared.send("conversations", method: "POST", body: body, accessToken: accessToken, idempotencyKey: UUID().uuidString)
    }

    static func list(accessToken: String, includeArchived: Bool = false, limit: Int = 50, offset: Int = 0) async throws -> ConversationPageDTO {
        try await APIClient.shared.send(
            "conversations?include_archived=\(includeArchived)&limit=\(limit)&offset=\(offset)",
            accessToken: accessToken
        )
    }

    static func get(_ id: UUID, accessToken: String) async throws -> ConversationPublicDTO {
        try await APIClient.shared.send("conversations/\(id.uuidString)", accessToken: accessToken)
    }

    static func update(_ id: UUID, accessToken: String, title: String? = nil, archived: Bool? = nil) async throws -> ConversationPublicDTO {
        let body = try BackendJSON.encoder.encode(ConversationUpdateRequest(title: title, archived: archived))
        return try await APIClient.shared.send("conversations/\(id.uuidString)", method: "PATCH", body: body, accessToken: accessToken)
    }

    static func delete(_ id: UUID, accessToken: String, deleteOrphanInspirations: Bool = false) async throws {
        let path = "conversations/\(id.uuidString)?delete_orphan_inspirations=\(deleteOrphanInspirations)"
        let _: EmptyResponse = try await APIClient.shared.send(path, method: "DELETE", accessToken: accessToken)
    }

    static func messages(_ conversationID: UUID, accessToken: String, afterSequence: Int = 0, limit: Int = 50) async throws -> ConversationMessagePageDTO {
        try await APIClient.shared.send(
            "conversations/\(conversationID.uuidString)/messages?after_sequence=\(afterSequence)&limit=\(limit)",
            accessToken: accessToken
        )
    }

    /// Sends a message and returns the full agent turn.
    static func sendMessage(_ conversationID: UUID, content: String, accessToken: String) async throws -> AgentTurnPublicDTO {
        let body = try BackendJSON.encoder.encode(ConversationMessageCreateRequest(content: content))
        return try await APIClient.shared.send(
            "conversations/\(conversationID.uuidString)/messages",
            method: "POST",
            body: body,
            accessToken: accessToken,
            idempotencyKey: UUID().uuidString
        )
    }
}
