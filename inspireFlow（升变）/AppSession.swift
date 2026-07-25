import Combine
import Foundation

enum UserRole: String, CaseIterable, Identifiable {
    case creator
    case client

    var id: Self { self }

    var title: String {
        switch self {
        case .creator: "创作者"
        case .client: "品牌方"
        }
    }

    var detail: String {
        switch self {
        case .creator: "捕捉灵感、完成创作与交付"
        case .client: "发布需求、管理验收与结算"
        }
    }

    var symbol: String {
        switch self {
        case .creator: "wand.and.stars"
        case .client: "briefcase.fill"
        }
    }
}

@MainActor
final class AppSession: ObservableObject {
    @Published private(set) var isAuthenticated: Bool
    @Published private(set) var role: UserRole
    @Published private(set) var displayName: String
    @Published private(set) var creatorProfile: CreatorProfile
    @Published private(set) var needsCreatorProfileSetup: Bool
    @Published private(set) var userID: UUID?
    @Published private(set) var isAuthenticating = false
    @Published private(set) var isDemoMode = false
    @Published var authErrorMessage: String?

    private let defaults: UserDefaults
    private let roleKey = "session.role"
    private let creatorProfileKey = "session.creatorProfile.v1"
    private let creatorProfileSetupKey = "session.needsCreatorProfileSetup"
    private let demoModeKey = "session.isDemoMode"

    var accessToken: String? {
        guard !isDemoMode else { return nil }
        return KeychainTokenStore.load()?.accessToken
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let savedDemo = defaults.bool(forKey: demoModeKey)
        isDemoMode = savedDemo
        role = UserRole(rawValue: defaults.string(forKey: roleKey) ?? "") ?? .creator

        let storedToken = KeychainTokenStore.load()
        let resolvedDisplayName: String

        if savedDemo {
            KeychainTokenStore.clear()
            isAuthenticated = true
            resolvedDisplayName = "演示用户"
            userID = nil
        } else if storedToken != nil {
            isAuthenticated = true
            resolvedDisplayName = storedToken!.nickname
            userID = storedToken!.userID
        } else {
            isAuthenticated = false
            resolvedDisplayName = ""
            userID = nil
        }
        displayName = resolvedDisplayName

        creatorProfile = defaults.data(forKey: creatorProfileKey)
            .flatMap { try? JSONDecoder().decode(CreatorProfile.self, from: $0) }
            ?? .empty(displayName: resolvedDisplayName)
        needsCreatorProfileSetup = savedDemo ? false : defaults.bool(forKey: creatorProfileSetupKey)
    }

    /// Re-validates a cached Keychain session against the backend on launch.
    /// Only a definitive `unauthorized` response signs the user out; network
    /// failures keep the optimistic local session so the app stays usable
    /// while the backend is unreachable.
    func restoreSession() async {
        guard let token = KeychainTokenStore.load() else { return }
        do {
            let user = try await AuthAPI.currentUser(accessToken: token.accessToken)
            displayName = user.nickname
            userID = user.id
        } catch APIClientError.unauthorized {
            signOut()
        } catch {
            // Backend unreachable or a transient failure: keep the local session.
        }
    }

    func loadCreatorProfile() async {
        guard let accessToken else { return }
        do {
            let remote = try await ProfileAPI.get(accessToken: accessToken)
            var updated = creatorProfile
            updated.displayName.value = displayName
            updated.biography.value = remote.bio ?? ""
            updated.creativeCategories.value = remote.contentFocus.joined(separator: "，")
            updated.collaborationAvailability.value = remote.collaborationPreferences ?? "暂不接受合作"
            updated.hasCompletedSetup = remote.bio != nil || !remote.contentFocus.isEmpty
            creatorProfile = updated
            persistCreatorProfile()
        } catch APIClientError.unauthorized {
            signOut()
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func signIn(nickname: String, password: String, role: UserRole) async -> Bool {
        await authenticate(nickname: nickname, password: password, role: role, isRegistering: false)
    }

    @discardableResult
    func register(nickname: String, password: String, role: UserRole) async -> Bool {
        await authenticate(nickname: nickname, password: password, role: role, isRegistering: true)
    }

    @discardableResult
    func signInOnlineDemo(role: UserRole) async -> Bool {
        isAuthenticating = true
        authErrorMessage = nil
        defer { isAuthenticating = false }

        do {
            let created = try await AuthAPI.demoLogin()
            applyAuthenticatedSession(created, role: role)
            return true
        } catch let error as APIClientError {
            if case .server(let status, _, _) = error, status == 404 {
                authErrorMessage = "platform.advx.uk 尚未启用在线演示账号，请部署 /api/v1/sessions/demo，或选择本地演示数据。"
            } else {
                authErrorMessage = Self.message(for: error)
            }
            return false
        } catch {
            authErrorMessage = "无法连接 platform.advx.uk，请稍后重试。"
            return false
        }
    }

    private func authenticate(nickname: String, password: String, role: UserRole, isRegistering: Bool) async -> Bool {
        isAuthenticating = true
        authErrorMessage = nil
        defer { isAuthenticating = false }

        do {
            if isRegistering {
                _ = try await AuthAPI.register(nickname: nickname, password: password)
            }
            let created = try await AuthAPI.login(nickname: nickname, password: password)
            applyAuthenticatedSession(created, role: role)

            if isRegistering && role == .creator {
                creatorProfile = .empty(displayName: displayName)
                needsCreatorProfileSetup = true
                persistCreatorProfile()
            }
            return true
        } catch let error as APIClientError {
            authErrorMessage = Self.message(for: error)
            return false
        } catch {
            authErrorMessage = "网络连接失败，请检查后端服务是否可用。"
            return false
        }
    }

    private func applyAuthenticatedSession(_ created: SessionCreatedDTO, role: UserRole) {
        KeychainTokenStore.save(
            .init(
                accessToken: created.accessToken,
                expiresAt: created.expiresAt,
                userID: created.user.id,
                nickname: created.user.nickname
            )
        )
        self.role = role
        displayName = created.user.nickname
        userID = created.user.id
        isDemoMode = false
        isAuthenticated = true
        defaults.set(false, forKey: demoModeKey)
        persistRole()
    }

    func saveCreatorProfile(_ profile: CreatorProfile) {
        creatorProfile = profile
        displayName = profile.displayName.value
        needsCreatorProfileSetup = false
        persistCreatorProfile()
    }

    @discardableResult
    func saveCreatorProfileRemotely(_ profile: CreatorProfile) async -> Bool {
        guard let accessToken else {
            saveCreatorProfile(profile)
            return true
        }

        let categories = profile.creativeCategories.value
            .split(whereSeparator: { $0 == "," || $0 == "，" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        do {
            _ = try await ProfileAPI.update(
                accessToken: accessToken,
                bio: profile.biography.value,
                preferredLanguage: Locale.current.identifier,
                creatorIdentity: profile.displayName.value,
                contentFocus: categories,
                collaborationPreferences: profile.collaborationAvailability.value
            )
            saveCreatorProfile(profile)
            return true
        } catch {
            authErrorMessage = error.localizedDescription
            return false
        }
    }

    func skipCreatorProfileSetup() {
        needsCreatorProfileSetup = false
        defaults.set(false, forKey: creatorProfileSetupKey)
    }

    /// Signs in as a local-only demo user — no backend, no Keychain, no onboard.
    /// Demo users can switch roles freely and reset local demo data from Account.
    func signInDemo(role: UserRole) {
        KeychainTokenStore.clear()
        self.role = role
        displayName = "演示用户"
        userID = nil
        isDemoMode = true
        isAuthenticated = true
        needsCreatorProfileSetup = false
        defaults.set(true, forKey: demoModeKey)
        persistRole()
    }

    func signOut() {
        isAuthenticated = false
        isDemoMode = false
        userID = nil
        defaults.set(false, forKey: demoModeKey)
        if let token = KeychainTokenStore.load() {
            Task { try? await AuthAPI.logout(accessToken: token.accessToken) }
        }
        KeychainTokenStore.clear()
    }

    func switchRole() {
        role = role == .creator ? .client : .creator
        persistRole()
    }

    private func persistRole() {
        defaults.set(role.rawValue, forKey: roleKey)
    }

    private func persistCreatorProfile() {
        if let data = try? JSONEncoder().encode(creatorProfile) {
            defaults.set(data, forKey: creatorProfileKey)
        }
        defaults.set(needsCreatorProfileSetup, forKey: creatorProfileSetupKey)
    }

    private static func message(for error: APIClientError) -> String {
        switch error {
        case .server(_, let code, let message):
            switch code {
            case "nickname_conflict": return "这个昵称已被使用，换一个试试。"
            case "invalid_credentials": return "昵称或密码不正确。"
            case "validation_error": return "昵称需 2-50 位，密码需 15-128 位。"
            default: return message
            }
        case .unauthorized: return "登录状态已失效，请重新登录。"
        case .transport: return "网络连接失败，请检查后端服务是否可用。"
        case .decoding, .invalidResponse: return "服务器返回了无法识别的数据。"
        }
    }
}