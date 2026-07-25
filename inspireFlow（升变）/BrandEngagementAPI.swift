import Foundation

// MARK: - Brand

struct BrandPublicDTO: Codable {
    let id: UUID
    let name: String
    let description: String?
    let websiteURL: String?
    let logoURL: String?
    let myRole: BrandRole?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case websiteURL = "website_url"
        case logoURL = "logo_url"
        case myRole = "my_role"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum BrandRole: String, Codable {
    case owner, member
}

struct BrandPageDTO: Codable {
    let items: [BrandPublicDTO]
    let total: Int
    let limit: Int
    let offset: Int
}

private struct BrandCreateRequest: Encodable {
    let name: String
    let description: String?
    let websiteURL: String?
    let logoURL: String?

    enum CodingKeys: String, CodingKey {
        case name, description
        case websiteURL = "website_url"
        case logoURL = "logo_url"
    }
}

private struct BrandUpdateRequest: Encodable {
    var name: String? = nil
    var description: String? = nil
    var websiteURL: String? = nil
    var logoURL: String? = nil

    enum CodingKeys: String, CodingKey {
        case name, description
        case websiteURL = "website_url"
        case logoURL = "logo_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(websiteURL, forKey: .websiteURL)
        try container.encodeIfPresent(logoURL, forKey: .logoURL)
    }
}

// MARK: - Brand Follow

struct BrandFollowPublicDTO: Codable {
    let id: UUID
    let brandID: UUID
    let creatorID: UUID
    let status: FollowStatus

    enum CodingKeys: String, CodingKey {
        case id
        case brandID = "brand_id"
        case creatorID = "creator_id"
        case status
    }
}

enum FollowStatus: String, Codable {
    case active, inactive
}

struct BrandFollowPageDTO: Codable {
    let items: [BrandFollowPublicDTO]
    let total: Int
    let limit: Int
    let offset: Int
}

// MARK: - Brand Interest

struct BrandInterestPublicDTO: Codable {
    let id: UUID
    let brandID: UUID
    let creatorID: UUID
    let projectID: UUID?
    let message: String?
    let status: InterestStatus
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case brandID = "brand_id"
        case creatorID = "creator_id"
        case projectID = "project_id"
        case message, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum InterestStatus: String, Codable {
    case pending, accepted, declined, withdrawn
}

struct BrandInterestPageDTO: Codable {
    let items: [BrandInterestPublicDTO]
    let total: Int
    let limit: Int
    let offset: Int
}

private struct BrandInterestCreateRequest: Encodable {
    let creatorID: UUID
    let projectID: UUID?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case creatorID = "creator_id"
        case projectID = "project_id"
        case message
    }
}

// MARK: - Brand Invitation

struct BrandInvitationPublicDTO: Codable {
    let id: UUID
    let brandID: UUID
    let inviteeUserID: UUID
    let role: BrandRole
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case brandID = "brand_id"
        case inviteeUserID = "invitee_user_id"
        case role, status
        case createdAt = "created_at"
    }
}

private struct BrandInvitationCreateRequest: Encodable {
    let inviteeUserID: UUID
    let role: BrandRole

    enum CodingKeys: String, CodingKey {
        case inviteeUserID = "invitee_user_id"
        case role
    }
}

// MARK: - Brand Membership

struct BrandMembershipPublicDTO: Codable {
    let userID: UUID
    let brandID: UUID
    let role: BrandRole
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case brandID = "brand_id"
        case role
        case createdAt = "created_at"
    }
}

private struct BrandMemberUpdateRequest: Encodable {
    let role: BrandRole
}

// MARK: - Creator Discovery

/// The backend returns `WorkshopPublic` items in the discovery page.
struct CreatorDiscoveryPageDTO: Codable {
    let items: [WorkshopPublicDTO]
    let total: Int
    let limit: Int
    let offset: Int
}

// MARK: - Creator Inbox

struct CreatorInboxPageDTO: Codable {
    let items: [CreatorInboxItemDTO]
    let total: Int
    let limit: Int
    let offset: Int
}

struct CreatorInboxItemDTO: Codable {
    let id: UUID
    let type: String
    let brandID: UUID?
    let brandName: String?
    let message: String?
    let isRead: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, type
        case brandID = "brand_id"
        case brandName = "brand_name"
        case message
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

private struct CreatorInboxMarkReadRequest: Encodable {
    let itemIDs: [UUID]

    enum CodingKeys: String, CodingKey {
        case itemIDs = "item_ids"
    }
}

// MARK: - Brand Engagement API

enum BrandEngagementAPI {
    // MARK: Brands

    static func create(
        name: String,
        description: String? = nil,
        websiteURL: String? = nil,
        logoURL: String? = nil,
        accessToken: String
    ) async throws -> BrandPublicDTO {
        let body = try BackendJSON.encoder.encode(
            BrandCreateRequest(name: name, description: description, websiteURL: websiteURL, logoURL: logoURL)
        )
        return try await APIClient.shared.send(
            "brands", method: "POST", body: body, accessToken: accessToken,
            idempotencyKey: UUID().uuidString
        )
    }

    static func list(accessToken: String, limit: Int = 50, offset: Int = 0) async throws -> BrandPageDTO {
        try await APIClient.shared.send("brands?limit=\(limit)&offset=\(offset)", accessToken: accessToken)
    }

    static func get(_ id: UUID, accessToken: String) async throws -> BrandPublicDTO {
        try await APIClient.shared.send("brands/\(id.uuidString)", accessToken: accessToken)
    }

    static func update(
        _ id: UUID,
        accessToken: String,
        name: String? = nil,
        description: String? = nil,
        websiteURL: String? = nil,
        logoURL: String? = nil
    ) async throws -> BrandPublicDTO {
        let body = try BackendJSON.encoder.encode(
            BrandUpdateRequest(name: name, description: description, websiteURL: websiteURL, logoURL: logoURL)
        )
        return try await APIClient.shared.send(
            "brands/\(id.uuidString)", method: "PATCH", body: body, accessToken: accessToken
        )
    }

    // MARK: Members

    static func members(_ brandID: UUID, accessToken: String) async throws -> [BrandMembershipPublicDTO] {
        try await APIClient.shared.send("brands/\(brandID.uuidString)/members", accessToken: accessToken)
    }

    static func updateMember(_ brandID: UUID, userID: UUID, role: BrandRole, accessToken: String) async throws {
        let body = try BackendJSON.encoder.encode(BrandMemberUpdateRequest(role: role))
        let _: EmptyResponse = try await APIClient.shared.send(
            "brands/\(brandID.uuidString)/members/\(userID.uuidString)",
            method: "PATCH", body: body, accessToken: accessToken
        )
    }

    static func removeMember(_ brandID: UUID, userID: UUID, accessToken: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.send(
            "brands/\(brandID.uuidString)/members/\(userID.uuidString)",
            method: "DELETE", accessToken: accessToken
        )
    }

    // MARK: Invitations

    static func createInvitation(_ brandID: UUID, inviteeUserID: UUID, role: BrandRole, accessToken: String) async throws -> BrandInvitationPublicDTO {
        let body = try BackendJSON.encoder.encode(BrandInvitationCreateRequest(inviteeUserID: inviteeUserID, role: role))
        return try await APIClient.shared.send(
            "brands/\(brandID.uuidString)/invitations",
            method: "POST", body: body, accessToken: accessToken,
            idempotencyKey: UUID().uuidString
        )
    }

    static func revokeInvitation(_ brandID: UUID, invitationID: UUID, accessToken: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.send(
            "brands/\(brandID.uuidString)/invitations/\(invitationID.uuidString)",
            method: "DELETE", accessToken: accessToken
        )
    }

    static func myInvitations(accessToken: String) async throws -> [BrandInvitationPublicDTO] {
        try await APIClient.shared.send("users/me/brand-invitations", accessToken: accessToken)
    }

    static func acceptInvitation(_ invitationID: UUID, accessToken: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.send(
            "users/me/brand-invitations/\(invitationID.uuidString)/accept",
            method: "POST", accessToken: accessToken,
            idempotencyKey: UUID().uuidString
        )
    }

    static func declineInvitation(_ invitationID: UUID, accessToken: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.send(
            "users/me/brand-invitations/\(invitationID.uuidString)/decline",
            method: "POST", accessToken: accessToken,
            idempotencyKey: UUID().uuidString
        )
    }

    // MARK: Follows

    static func follows(_ brandID: UUID, accessToken: String, limit: Int = 50, offset: Int = 0) async throws -> BrandFollowPageDTO {
        try await APIClient.shared.send("brands/\(brandID.uuidString)/follows?limit=\(limit)&offset=\(offset)", accessToken: accessToken)
    }

    static func follow(_ brandID: UUID, creatorID: UUID, accessToken: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.send(
            "brands/\(brandID.uuidString)/follows/\(creatorID.uuidString)",
            method: "PUT", accessToken: accessToken
        )
    }

    static func unfollow(_ brandID: UUID, creatorID: UUID, accessToken: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.send(
            "brands/\(brandID.uuidString)/follows/\(creatorID.uuidString)",
            method: "DELETE", accessToken: accessToken
        )
    }

    // MARK: Creator Discovery

    static func discoverCreators(
        _ brandID: UUID,
        accessToken: String,
        query: String? = nil,
        contentFocus: [String]? = nil,
        sortBy: String = "updated_at",
        sortOrder: String = "desc",
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> CreatorDiscoveryPageDTO {
        var components: [String] = ["limit=\(limit)", "offset=\(offset)", "sort_by=\(sortBy)", "sort_order=\(sortOrder)"]
        if let query { components.append("query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)") }
        if let contentFocus, !contentFocus.isEmpty {
            components.append("content_focus=\(contentFocus.joined(separator: ",").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        }
        let path = "brands/\(brandID.uuidString)/creator-discovery?\(components.joined(separator: "&"))"
        return try await APIClient.shared.send(path, accessToken: accessToken)
    }

    // MARK: Interests

    static func interests(_ brandID: UUID, accessToken: String, limit: Int = 50, offset: Int = 0) async throws -> BrandInterestPageDTO {
        try await APIClient.shared.send("brands/\(brandID.uuidString)/interests?limit=\(limit)&offset=\(offset)", accessToken: accessToken)
    }

    static func createInterest(
        _ brandID: UUID,
        creatorID: UUID,
        projectID: UUID? = nil,
        message: String? = nil,
        accessToken: String
    ) async throws -> BrandInterestPublicDTO {
        let body = try BackendJSON.encoder.encode(
            BrandInterestCreateRequest(creatorID: creatorID, projectID: projectID, message: message)
        )
        return try await APIClient.shared.send(
            "brands/\(brandID.uuidString)/interests",
            method: "POST", body: body, accessToken: accessToken,
            idempotencyKey: UUID().uuidString
        )
    }

    static func withdrawInterest(_ brandID: UUID, interestID: UUID, accessToken: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.send(
            "brands/\(brandID.uuidString)/interests/\(interestID.uuidString)",
            method: "PATCH", accessToken: accessToken
        )
    }

    // MARK: Creator Inbox

    static func creatorInbox(accessToken: String, limit: Int = 50, offset: Int = 0) async throws -> CreatorInboxPageDTO {
        try await APIClient.shared.send("users/me/brand-inbox?limit=\(limit)&offset=\(offset)", accessToken: accessToken)
    }

    static func markInboxRead(_ itemIDs: [UUID], accessToken: String) async throws {
        let body = try BackendJSON.encoder.encode(CreatorInboxMarkReadRequest(itemIDs: itemIDs))
        let _: EmptyResponse = try await APIClient.shared.send(
            "users/me/brand-inbox/mark-read",
            method: "POST", body: body, accessToken: accessToken
        )
    }
}
