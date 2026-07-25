import Foundation

// MARK: - DTOs (matches live /openapi.json)

struct ProjectPublicDTO: Decodable {
    let id: UUID
    let userID: UUID
    let title: String
    let type: String
    let audience: String
    let summary: String
    let iconURL: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case title, type, audience, summary
        case iconURL = "icon_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ProjectDetailDTO: Decodable {
    let id: UUID
    let userID: UUID
    let title: String
    let type: String
    let audience: String
    let summary: String
    let iconURL: String?
    let createdAt: Date
    let updatedAt: Date
    let inspirationCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case title, type, audience, summary
        case iconURL = "icon_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case inspirationCount = "inspiration_count"
    }
}

struct ProjectPageDTO: Decodable {
    let items: [ProjectPublicDTO]
    let total: Int
    let limit: Int
    let offset: Int
}

struct ProjectDraftDTO: Decodable {
    let title: String
    let type: String
    let audience: String
    let summary: String
    let iconURL: String?

    enum CodingKeys: String, CodingKey {
        case title, type, audience, summary
        case iconURL = "icon_url"
    }
}

private struct ProjectCreateRequest: Encodable {
    let title: String
    let type: String
    let audience: String
    let summary: String
    let iconURL: String?

    enum CodingKeys: String, CodingKey {
        case title, type, audience, summary
        case iconURL = "icon_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(type, forKey: .type)
        try container.encode(audience, forKey: .audience)
        try container.encode(summary, forKey: .summary)
        try container.encodeIfPresent(iconURL, forKey: .iconURL)
    }
}

private struct ProjectDraftRequest: Encodable {
    let description: String
}

private struct ProjectUpdateRequest: Encodable {
    var title: String? = nil
    var type: String? = nil
    var audience: String? = nil
    var summary: String? = nil
    var iconURL: String? = nil

    enum CodingKeys: String, CodingKey {
        case title, type, audience, summary
        case iconURL = "icon_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(audience, forKey: .audience)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encodeIfPresent(iconURL, forKey: .iconURL)
    }
}

// MARK: - Project API

enum ProjectAPI {
    /// Generate an editable draft from a free-text description (needs model configured).
    static func draft(
        description: String,
        accessToken: String
    ) async throws -> ProjectDraftDTO {
        let body = try BackendJSON.encoder.encode(ProjectDraftRequest(description: description))
        return try await APIClient.shared.send("projects/drafts", method: "POST", body: body, accessToken: accessToken, idempotencyKey: UUID().uuidString)
    }

    /// Create a project from the validated fields.
    static func create(
        accessToken: String,
        title: String,
        type: String,
        audience: String,
        summary: String,
        iconURL: String? = nil
    ) async throws -> ProjectPublicDTO {
        let body = try BackendJSON.encoder.encode(
            ProjectCreateRequest(title: title, type: type, audience: audience, summary: summary, iconURL: iconURL)
        )
        return try await APIClient.shared.send("projects", method: "POST", body: body, accessToken: accessToken, idempotencyKey: UUID().uuidString)
    }

    /// List projects (sorted by recent update descending).
    static func list(
        accessToken: String,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> ProjectPageDTO {
        try await APIClient.shared.send("projects?limit=\(limit)&offset=\(offset)", accessToken: accessToken)
    }

    /// Read a single project with its inspiration count.
    static func get(_ id: UUID, accessToken: String) async throws -> ProjectDetailDTO {
        try await APIClient.shared.send("projects/\(id.uuidString)", accessToken: accessToken)
    }

    /// Patch one or more fields. Pass `nil` to leave a field unchanged.
    static func update(
        _ id: UUID,
        accessToken: String,
        title: String? = nil,
        type: String? = nil,
        audience: String? = nil,
        summary: String? = nil,
        iconURL: String? = nil
    ) async throws -> ProjectPublicDTO {
        let body = try BackendJSON.encoder.encode(
            ProjectUpdateRequest(title: title, type: type, audience: audience, summary: summary, iconURL: iconURL)
        )
        return try await APIClient.shared.send("projects/\(id.uuidString)", method: "PATCH", body: body, accessToken: accessToken)
    }

    /// Delete a project. Optionally also deletes orphaned inspirations.
    static func delete(
        _ id: UUID,
        accessToken: String,
        deleteOrphanInspirations: Bool = false
    ) async throws {
        let path = "projects/\(id.uuidString)?delete_orphan_inspirations=\(deleteOrphanInspirations)"
        let _: EmptyResponse = try await APIClient.shared.send(path, method: "DELETE", accessToken: accessToken)
    }

    /// List inspirations linked to a specific project.
    static func inspirations(
        projectID: UUID,
        accessToken: String,
        status: InspirationStatus? = nil,
        sourceType: InspirationSourceType? = nil,
        query: String? = nil,
        sortBy: String = "updated_at",
        sortOrder: String = "desc",
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> InspirationPageDTO {
        var components: [String] = []
        if let status { components.append("status=\(status.rawValue)") }
        if let sourceType { components.append("source_type=\(sourceType.rawValue)") }
        if let query { components.append("query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)") }
        components.append("sort_by=\(sortBy)")
        components.append("sort_order=\(sortOrder)")
        components.append("limit=\(limit)")
        components.append("offset=\(offset)")
        let path = "projects/\(projectID.uuidString)/inspirations?\(components.joined(separator: "&"))"
        return try await APIClient.shared.send(path, accessToken: accessToken)
    }
}
