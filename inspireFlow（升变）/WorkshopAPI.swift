import Foundation

// MARK: - Workshop Public

struct WorkshopPublicDTO: Codable {
    let creatorID: UUID
    let nickname: String
    let avatarURL: String?
    let title: String?
    let bio: String?
    let creatorIdentity: String?
    let contentFocus: [String]?
    let collaborationPreferences: String?
    let socialAccounts: [WorkshopSocialAccountPublicDTO]
    let contacts: [WorkshopContactPublicDTO]
    let projects: [WorkshopProjectCardPublicDTO]
    let publishedAt: Date?

    enum CodingKeys: String, CodingKey {
        case creatorID = "creator_id"
        case nickname
        case avatarURL = "avatar_url"
        case title, bio
        case creatorIdentity = "creator_identity"
        case contentFocus = "content_focus"
        case collaborationPreferences = "collaboration_preferences"
        case socialAccounts = "social_accounts"
        case contacts, projects
        case publishedAt = "published_at"
    }
}

enum WorkshopVisibility: String, Codable {
    case `private` = "private"
    case workshopPublic = "workshop_public"
    case brandsOnly = "brands_only"
    case authorizedBrands = "authorized_brands"

    var title: String {
        switch self {
        case .private: "不公开"
        case .workshopPublic: "所有人可见"
        case .brandsOnly: "品牌方可见"
        case .authorizedBrands: "已授权品牌可见"
        }
    }
}

// MARK: - Workshop Social Account

struct WorkshopSocialAccountPublicDTO: Codable, Identifiable {
    let id: UUID
    let platform: SocialPlatform
    let handle: String?
    let displayName: String?
    let isVerified: Bool?
    let followerCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, platform, handle
        case displayName = "display_name"
        case isVerified = "is_verified"
        case followerCount = "follower_count"
    }
}

enum SocialPlatform: String, Codable, CaseIterable {
    case bilibili, douyin, xiaohongshu, weibo, zhihu, youtube, other

    var title: String {
        switch self {
        case .bilibili: "Bilibili"
        case .douyin: "抖音"
        case .xiaohongshu: "小红书"
        case .weibo: "微博"
        case .zhihu: "知乎"
        case .youtube: "YouTube"
        case .other: "其他"
        }
    }

    var symbol: String {
        switch self {
        case .bilibili: "b.circle.fill"
        case .douyin: "music.note"
        case .xiaohongshu: "book.fill"
        case .weibo: "antenna.radiowaves.left.and.right"
        case .zhihu: "questionmark.circle.fill"
        case .youtube: "play.rectangle.fill"
        case .other: "link"
        }
    }
}

// MARK: - Workshop Contact

struct WorkshopContactPublicDTO: Codable, Identifiable {
    let id: UUID
    let type: ContactType
    let label: String?
    let value: String
    let actionURI: String?
    let visibility: ContactVisibility?
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, type, label, value
        case actionURI = "action_uri"
        case visibility
        case sortOrder = "sort_order"
    }
}

enum ContactType: String, Codable, CaseIterable {
    case email, phone, wechat, qq, telegram, other

    var title: String {
        switch self {
        case .email: "邮箱"
        case .phone: "电话"
        case .wechat: "微信"
        case .qq: "QQ"
        case .telegram: "Telegram"
        case .other: "其他"
        }
    }

    var symbol: String {
        switch self {
        case .email: "envelope.fill"
        case .phone: "phone.fill"
        case .wechat: "message.fill"
        case .qq: "paperplane.fill"
        case .telegram: "arrow.up.message.fill"
        case .other: "ellipsis.message.fill"
        }
    }
}

enum ContactVisibility: String, Codable {
    case `private` = "private"
    case authorizedBrands = "authorized_brands"
}

// MARK: - Workshop Project Card

struct WorkshopProjectCardPublicDTO: Codable, Identifiable {
    let projectID: UUID?
    let title: String
    let type: String?
    let summary: String?
    let coverURL: String?

    enum CodingKeys: String, CodingKey {
        case projectID = "project_id"
        case title, type, summary
        case coverURL = "cover_url"
    }

    var id: String { projectID?.uuidString ?? title }
}

// MARK: - Brand Authorization

struct WorkshopBrandAuthorizationPublicDTO: Codable {
    let brandID: UUID
    let brandName: String
    let authorizedAt: Date

    enum CodingKeys: String, CodingKey {
        case brandID = "brand_id"
        case brandName = "brand_name"
        case authorizedAt = "authorized_at"
    }
}

// MARK: - Request bodies

private struct WorkshopUpdateRequest: Encodable {
    var nickname: String? = nil
    var avatarURL: String? = nil
    var title: String? = nil
    var bio: String? = nil
    var creatorIdentity: String? = nil
    var contentFocus: [String]? = nil
    var collaborationPreferences: String? = nil
    var nicknameVisibility: WorkshopVisibility? = nil
    var avatarVisibility: WorkshopVisibility? = nil
    var titleVisibility: WorkshopVisibility? = nil
    var bioVisibility: WorkshopVisibility? = nil
    var creatorIdentityVisibility: WorkshopVisibility? = nil
    var contentFocusVisibility: WorkshopVisibility? = nil
    var collaborationPreferencesVisibility: WorkshopVisibility? = nil

    enum CodingKeys: String, CodingKey {
        case nickname, title, bio
        case avatarURL = "avatar_url"
        case creatorIdentity = "creator_identity"
        case contentFocus = "content_focus"
        case collaborationPreferences = "collaboration_preferences"
        case nicknameVisibility = "nickname_visibility"
        case avatarVisibility = "avatar_visibility"
        case titleVisibility = "title_visibility"
        case bioVisibility = "bio_visibility"
        case creatorIdentityVisibility = "creator_identity_visibility"
        case contentFocusVisibility = "content_focus_visibility"
        case collaborationPreferencesVisibility = "collaboration_preferences_visibility"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(nickname, forKey: .nickname)
        try container.encodeIfPresent(avatarURL, forKey: .avatarURL)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encodeIfPresent(creatorIdentity, forKey: .creatorIdentity)
        try container.encodeIfPresent(contentFocus, forKey: .contentFocus)
        try container.encodeIfPresent(collaborationPreferences, forKey: .collaborationPreferences)
        try container.encodeIfPresent(nicknameVisibility, forKey: .nicknameVisibility)
        try container.encodeIfPresent(avatarVisibility, forKey: .avatarVisibility)
        try container.encodeIfPresent(titleVisibility, forKey: .titleVisibility)
        try container.encodeIfPresent(bioVisibility, forKey: .bioVisibility)
        try container.encodeIfPresent(creatorIdentityVisibility, forKey: .creatorIdentityVisibility)
        try container.encodeIfPresent(contentFocusVisibility, forKey: .contentFocusVisibility)
        try container.encodeIfPresent(collaborationPreferencesVisibility, forKey: .collaborationPreferencesVisibility)
    }
}

private struct WorkshopContactCreateRequest: Encodable {
    let type: ContactType
    let label: String?
    let value: String
    let visibility: ContactVisibility
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case type, label, value, visibility
        case sortOrder = "sort_order"
    }
}

private struct WorkshopContactUpdateRequest: Encodable {
    var type: ContactType? = nil
    var label: String? = nil
    var value: String? = nil
    var visibility: ContactVisibility? = nil
    var sortOrder: Int? = nil

    enum CodingKeys: String, CodingKey {
        case type, label, value, visibility
        case sortOrder = "sort_order"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(label, forKey: .label)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(visibility, forKey: .visibility)
        try container.encodeIfPresent(sortOrder, forKey: .sortOrder)
    }
}

private struct WorkshopSocialAccountCreateRequest: Encodable {
    let platform: SocialPlatform
    let handle: String?

    enum CodingKeys: String, CodingKey { case platform, handle }
}

private struct WorkshopSocialAccountUpdateRequest: Encodable {
    var handle: String? = nil

    enum CodingKeys: String, CodingKey { case handle }
}

private struct WorkshopProjectSelectionUpdateRequest: Encodable {
    let projectID: UUID

    enum CodingKeys: String, CodingKey {
        case projectID = "project_id"
    }
}

// MARK: - Workshop API

enum WorkshopAPI {
    // MARK: Workshop

    /// Read my workshop (draft or published).
    static func myWorkshop(accessToken: String) async throws -> WorkshopPublicDTO {
        try await APIClient.shared.send("users/me/workshop", accessToken: accessToken)
    }

    /// Patch my workshop fields.
    static func update(
        accessToken: String,
        nickname: String? = nil,
        avatarURL: String? = nil,
        title: String? = nil,
        bio: String? = nil,
        creatorIdentity: String? = nil,
        contentFocus: [String]? = nil,
        collaborationPreferences: String? = nil,
        nicknameVisibility: WorkshopVisibility? = nil,
        avatarVisibility: WorkshopVisibility? = nil,
        titleVisibility: WorkshopVisibility? = nil,
        bioVisibility: WorkshopVisibility? = nil,
        creatorIdentityVisibility: WorkshopVisibility? = nil,
        contentFocusVisibility: WorkshopVisibility? = nil,
        collaborationPreferencesVisibility: WorkshopVisibility? = nil
    ) async throws -> WorkshopPublicDTO {
        let body = try BackendJSON.encoder.encode(
            WorkshopUpdateRequest(
                nickname: nickname, avatarURL: avatarURL, title: title, bio: bio,
                creatorIdentity: creatorIdentity, contentFocus: contentFocus,
                collaborationPreferences: collaborationPreferences,
                nicknameVisibility: nicknameVisibility, avatarVisibility: avatarVisibility,
                titleVisibility: titleVisibility, bioVisibility: bioVisibility,
                creatorIdentityVisibility: creatorIdentityVisibility,
                contentFocusVisibility: contentFocusVisibility,
                collaborationPreferencesVisibility: collaborationPreferencesVisibility
            )
        )
        return try await APIClient.shared.send("users/me/workshop", method: "PATCH", body: body, accessToken: accessToken)
    }

    /// Preview my workshop as others see it.
    static func preview(accessToken: String) async throws -> WorkshopPublicDTO {
        try await APIClient.shared.send("users/me/workshop/preview", accessToken: accessToken)
    }

    /// Publish my workshop.
    static func publish(accessToken: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.send(
            "users/me/workshop/publish", method: "POST", accessToken: accessToken,
            idempotencyKey: UUID().uuidString
        )
    }

    /// Withdraw my workshop from public view.
    static func withdraw(accessToken: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.send(
            "users/me/workshop/withdraw", method: "POST", accessToken: accessToken,
            idempotencyKey: UUID().uuidString
        )
    }

    /// View another creator's published workshop.
    static func view(creatorID: UUID, accessToken: String) async throws -> WorkshopPublicDTO {
        try await APIClient.shared.send("workshops/\(creatorID.uuidString)", accessToken: accessToken)
    }

    // MARK: Social Accounts

    static func createSocialAccount(platform: SocialPlatform, handle: String?, accessToken: String) async throws -> WorkshopSocialAccountPublicDTO {
        let body = try BackendJSON.encoder.encode(WorkshopSocialAccountCreateRequest(platform: platform, handle: handle))
        return try await APIClient.shared.send(
            "users/me/workshop/social-accounts", method: "POST", body: body, accessToken: accessToken,
            idempotencyKey: UUID().uuidString
        )
    }

    static func updateSocialAccount(_ accountID: UUID, handle: String?, accessToken: String) async throws -> WorkshopSocialAccountPublicDTO {
        let body = try BackendJSON.encoder.encode(WorkshopSocialAccountUpdateRequest(handle: handle))
        return try await APIClient.shared.send(
            "users/me/workshop/social-accounts/\(accountID.uuidString)", method: "PATCH", body: body, accessToken: accessToken
        )
    }

    static func removeSocialAccount(_ accountID: UUID, accessToken: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.send(
            "users/me/workshop/social-accounts/\(accountID.uuidString)", method: "DELETE", accessToken: accessToken
        )
    }

    // MARK: Contacts

    static func createContact(type: ContactType, label: String?, value: String, visibility: ContactVisibility = .private, sortOrder: Int = 0, accessToken: String) async throws -> WorkshopContactPublicDTO {
        let body = try BackendJSON.encoder.encode(
            WorkshopContactCreateRequest(type: type, label: label, value: value, visibility: visibility, sortOrder: sortOrder)
        )
        return try await APIClient.shared.send(
            "users/me/workshop/contacts", method: "POST", body: body, accessToken: accessToken,
            idempotencyKey: UUID().uuidString
        )
    }

    static func updateContact(_ contactID: UUID, type: ContactType? = nil, label: String? = nil, value: String? = nil, visibility: ContactVisibility? = nil, sortOrder: Int? = nil, accessToken: String) async throws -> WorkshopContactPublicDTO {
        let body = try BackendJSON.encoder.encode(
            WorkshopContactUpdateRequest(type: type, label: label, value: value, visibility: visibility, sortOrder: sortOrder)
        )
        return try await APIClient.shared.send(
            "users/me/workshop/contacts/\(contactID.uuidString)", method: "PATCH", body: body, accessToken: accessToken
        )
    }

    static func removeContact(_ contactID: UUID, accessToken: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.send(
            "users/me/workshop/contacts/\(contactID.uuidString)", method: "DELETE", accessToken: accessToken
        )
    }

    // MARK: Projects

    /// Add a project to workshop display.
    static func addProject(_ projectID: UUID, accessToken: String) async throws {
        let body = try BackendJSON.encoder.encode(WorkshopProjectSelectionUpdateRequest(projectID: projectID))
        let _: EmptyResponse = try await APIClient.shared.send(
            "users/me/workshop/projects/\(projectID.uuidString)", method: "PUT", body: body, accessToken: accessToken
        )
    }

    /// Remove a project from workshop display.
    static func removeProject(_ projectID: UUID, accessToken: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.send(
            "users/me/workshop/projects/\(projectID.uuidString)", method: "DELETE", accessToken: accessToken
        )
    }

    // MARK: Brand Authorizations

    static func brandAuthorizations(accessToken: String) async throws -> [WorkshopBrandAuthorizationPublicDTO] {
        try await APIClient.shared.send("users/me/workshop/brand-authorizations", accessToken: accessToken)
    }

    static func authorizeBrand(_ brandID: UUID, accessToken: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.send(
            "users/me/workshop/brand-authorizations/\(brandID.uuidString)", method: "PUT", accessToken: accessToken
        )
    }

    static func deauthorizeBrand(_ brandID: UUID, accessToken: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.send(
            "users/me/workshop/brand-authorizations/\(brandID.uuidString)", method: "DELETE", accessToken: accessToken
        )
    }
}
