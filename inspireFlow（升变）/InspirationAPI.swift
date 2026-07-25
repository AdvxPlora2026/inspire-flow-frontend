import Foundation

// MARK: - DTOs (matches live /openapi.json)

enum InspirationStatus: String, Codable {
    case inbox, developing, converted, archived
}

enum InspirationSourceType: String, Codable {
    case manual, agent, voice
}

struct InspirationProjectSummaryDTO: Codable {
    let id: UUID
    let title: String
    let iconURL: String?

    enum CodingKeys: String, CodingKey {
        case id, title
        case iconURL = "icon_url"
    }
}

struct InspirationPublicDTO: Codable {
    let id: UUID
    let userID: UUID
    let title: String?
    let content: String
    let status: InspirationStatus
    let sourceType: InspirationSourceType
    let sourceConversationID: UUID?
    let sourceMessageID: UUID?
    let projects: [InspirationProjectSummaryDTO]
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case title, content, status
        case sourceType = "source_type"
        case sourceConversationID = "source_conversation_id"
        case sourceMessageID = "source_message_id"
        case projects
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct InspirationPageDTO: Decodable {
    let items: [InspirationPublicDTO]
    let total: Int
    let limit: Int
    let offset: Int
}

private struct InspirationCreateRequest: Encodable {
    let title: String? = nil
    let content: String
    let sourceType: InspirationSourceType
    let projectIDs: [UUID]

    enum CodingKeys: String, CodingKey {
        case title, content
        case sourceType = "source_type"
        case projectIDs = "project_ids"
    }
}

private struct InspirationUpdateRequest: Encodable {
    var title: String? = nil
    var content: String? = nil
    var status: InspirationStatus? = nil
    var projectIDs: [UUID]? = nil

    enum CodingKeys: String, CodingKey {
        case title, content, status
        case projectIDs = "project_ids"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(projectIDs, forKey: .projectIDs)
    }
}

// MARK: - Inspiration API

/// Maps to `InspirationCapture` in the frontend.
///
/// Backend statuses: `inbox | developing | converted | archived`
/// Backend source types: `manual | agent | voice`
enum InspirationAPI {
    static func create(
        accessToken: String,
        content: String,
        title: String? = nil,
        sourceType: InspirationSourceType = .manual,
        projectIDs: [UUID] = []
    ) async throws -> InspirationPublicDTO {
        let body = try BackendJSON.encoder.encode(
            InspirationCreateRequest(content: content, sourceType: sourceType, projectIDs: projectIDs)
        )
        return try await APIClient.shared.send("inspirations", method: "POST", body: body, accessToken: accessToken, idempotencyKey: UUID().uuidString)
    }

    static func list(
        accessToken: String,
        projectID: UUID? = nil,
        status: InspirationStatus? = nil,
        sourceType: InspirationSourceType? = nil,
        query: String? = nil,
        sortBy: String = "updated_at",
        sortOrder: String = "desc",
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> InspirationPageDTO {
        var components: [String] = []
        if let projectID { components.append("project_id=\(projectID.uuidString)") }
        if let status { components.append("status=\(status.rawValue)") }
        if let sourceType { components.append("source_type=\(sourceType.rawValue)") }
        if let query { components.append("query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)") }
        components.append("sort_by=\(sortBy)")
        components.append("sort_order=\(sortOrder)")
        components.append("limit=\(limit)")
        components.append("offset=\(offset)")
        let path = "inspirations?\(components.joined(separator: "&"))"
        return try await APIClient.shared.send(path, accessToken: accessToken)
    }

    static func get(_ id: UUID, accessToken: String) async throws -> InspirationPublicDTO {
        try await APIClient.shared.send("inspirations/\(id.uuidString)", accessToken: accessToken)
    }

    static func update(
        _ id: UUID,
        accessToken: String,
        title: String? = nil,
        content: String? = nil,
        status: InspirationStatus? = nil,
        projectIDs: [UUID]? = nil
    ) async throws -> InspirationPublicDTO {
        let body = try BackendJSON.encoder.encode(
            InspirationUpdateRequest(title: title, content: content, status: status, projectIDs: projectIDs)
        )
        return try await APIClient.shared.send("inspirations/\(id.uuidString)", method: "PATCH", body: body, accessToken: accessToken)
    }

    static func delete(_ id: UUID, accessToken: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.send(
            "inspirations/\(id.uuidString)", method: "DELETE", accessToken: accessToken
        )
    }

    /// Link an inspiration to a project.
    static func addProjectLink(
        _ inspirationID: UUID,
        projectID: UUID,
        accessToken: String
    ) async throws {
        let _: EmptyResponse = try await APIClient.shared.send(
            "inspirations/\(inspirationID.uuidString)/projects/\(projectID.uuidString)",
            method: "PUT",
            accessToken: accessToken
        )
    }

    /// Unlink an inspiration from a project.
    static func removeProjectLink(
        _ inspirationID: UUID,
        projectID: UUID,
        accessToken: String
    ) async throws {
        let _: EmptyResponse = try await APIClient.shared.send(
            "inspirations/\(inspirationID.uuidString)/projects/\(projectID.uuidString)",
            method: "DELETE",
            accessToken: accessToken
        )
    }
}
