import Combine
import Foundation

// MARK: - Inspiration

struct PawnQA: Codable, Identifiable, Hashable {
    let id: UUID
    let question: String
    let answer: String
}

struct BilibiliPack: Codable, Hashable {
    var title: String
    var hook: String
    var outline: String
    var shotList: String
}

enum InspirationPrivacy: String, Codable, CaseIterable, Identifiable {
    case privateOnly
    case projectMembers
    case publicContent

    var id: Self { self }

    var title: String {
        switch self {
        case .privateOnly: "私密"
        case .projectMembers: "项目成员"
        case .publicContent: "公开"
        }
    }

    var symbol: String {
        switch self {
        case .privateOnly: "lock.fill"
        case .projectMembers: "person.2.fill"
        case .publicContent: "globe.asia.australia.fill"
        }
    }
}

struct InspirationCapture: Codable, Identifiable, Hashable {
    let id: UUID
    var transcription: String
    var pawnQAs: [PawnQA]
    var bilibiliPack: BilibiliPack?
    var projectID: UUID?
    var privacy: InspirationPrivacy
    var createdAt: Date
    var isDemoFallback: Bool

    static func demo() -> InspirationCapture {
        InspirationCapture(
            id: UUID(),
            transcription: "我想做一期关于随手用语音捕捉灵感、再由 PAWN 完成 B 站创作方案的视频。",
            pawnQAs: [
                PawnQA(id: UUID(), question: "这条视频最想讲给谁看？", answer: "第一次尝试无屏创作的 B 站创作者"),
                PawnQA(id: UUID(), question: "你希望它是什么形式？", answer: "60 秒现场竖屏短视频"),
                PawnQA(id: UUID(), question: "最重要的开场画面是什么？", answer: "创作者正在拍摄，却突然冒出一个灵感")
            ],
            bilibiliPack: BilibiliPack(
                title: "我用一句话，接住了差点消失的灵感",
                hook: "最好的创作工具，也许根本没有屏幕。",
                outline: "灵感丢失 → 一句话录下 → PAWN 追问 → 成片",
                shotList: "现场走拍、开口瞬间、追问反馈、方案结果页"
            ),
            projectID: nil,
            privacy: .privateOnly,
            createdAt: .now,
            isDemoFallback: true
        )
    }
}

// MARK: - Project

enum ProjectKind: String, Codable, CaseIterable, Identifiable {
    case personal
    case commercial

    var id: String { rawValue }

    var title: String {
        switch self {
        case .personal: "个人创作"
        case .commercial: "商业委托"
        }
    }

    static func inferred(from type: String) -> ProjectKind {
        let normalized = type.lowercased()
        let commercialMarkers = ["商业", "委托", "品牌", "commercial", "brand", "brief"]
        return commercialMarkers.contains(where: normalized.contains) ? .commercial : .personal
    }
}

enum ProjectStage: String, Codable, CaseIterable {
    case brief
    case creating
    case review
    case approved
    case settled

    var title: String {
        switch self {
        case .brief: "需求确认"
        case .creating: "创作中"
        case .review: "待验收"
        case .approved: "已验收"
        case .settled: "已结算"
        }
    }

    var progress: Double {
        switch self {
        case .brief: 0.15
        case .creating: 0.45
        case .review: 0.7
        case .approved: 0.9
        case .settled: 1
        }
    }

    var actionTitle: String {
        switch self {
        case .brief: "开始创作"
        case .creating: "提交验收"
        case .review: "确认验收"
        case .approved: "确认结算"
        case .settled: "已完成"
        }
    }
}

struct CreatorProject: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var initialIdea: String
    var kind: ProjectKind
    var stage: ProjectStage
    var createdAt: Date

    static let demo = CreatorProject(
        id: UUID(),
        name: "AdventureX 创作幕后",
        initialIdea: "记录随手用语音捕捉灵感，再由 PAWN 完成 B 站创作方案的全过程。",
        kind: .commercial,
        stage: .creating,
        createdAt: .now
    )
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var projects: [CreatorProject]
    @Published private(set) var pawnConversations: [PawnConversation]
    @Published private(set) var inspirations: [InspirationCapture]
    @Published private(set) var isSyncing = false
    @Published private(set) var syncErrorMessage: String?

    private let storageKey = "creatorProjects.v1"
    private let pawnConversationsStorageKey = "pawnConversations.v1"
    private let inspirationsStorageKey = "inspirations.v1"
    private let remoteConversationIDsKey = "remoteConversationIDs.v1"
    private let defaults: UserDefaults
    private var remoteConversationIDs: [UUID: UUID]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        remoteConversationIDs = defaults.data(forKey: remoteConversationIDsKey)
            .flatMap { try? JSONDecoder().decode([UUID: UUID].self, from: $0) }
            ?? [:]
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([CreatorProject].self, from: data) {
            projects = decoded
        } else {
            projects = [.demo]
        }

        if let data = defaults.data(forKey: pawnConversationsStorageKey),
           let decoded = try? JSONDecoder().decode([PawnConversation].self, from: data) {
            pawnConversations = decoded
        } else {
            pawnConversations = []
        }

        if let data = defaults.data(forKey: inspirationsStorageKey),
           let decoded = try? JSONDecoder().decode([InspirationCapture].self, from: data) {
            inspirations = decoded
        } else {
            inspirations = [.demo()]
        }
    }

    @discardableResult
    func createProject(name: String, initialIdea: String, kind: ProjectKind = .personal) -> CreatorProject {
        let project = CreatorProject(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            initialIdea: initialIdea.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            stage: .brief,
            createdAt: .now
        )
        projects.insert(project, at: 0)
        persist()
        return project
    }

    @discardableResult
    func createProject(
        name: String,
        initialIdea: String,
        kind: ProjectKind = .personal,
        contentType: String = "视频",
        audience: String = "内容创作者",
        accessToken: String?
    ) async throws -> CreatorProject {
        guard let accessToken else {
            return createProject(name: name, initialIdea: initialIdea, kind: kind)
        }

        let remote = try await ProjectAPI.create(
            accessToken: accessToken,
            title: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: contentType,
            audience: audience,
            summary: initialIdea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "从 inspireFlow 创建的项目"
                : initialIdea.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let project = CreatorProject(
            id: remote.id,
            name: remote.title,
            initialIdea: remote.summary,
            kind: kind,
            stage: .brief,
            createdAt: remote.createdAt
        )
        projects.removeAll { $0.id == project.id }
        projects.insert(project, at: 0)
        persist()
        return project
    }

    func syncRemoteData(accessToken: String?) async {
        guard let accessToken else { return }
        isSyncing = true
        syncErrorMessage = nil
        defer { isSyncing = false }

        do {
            async let projectPage = ProjectAPI.list(accessToken: accessToken)
            async let inspirationPage = InspirationAPI.list(accessToken: accessToken)
            let (remoteProjects, remoteInspirations) = try await (projectPage, inspirationPage)

            let localProjectsByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
            projects = remoteProjects.items.map { item in
                let overlay = localProjectsByID[item.id]
                return CreatorProject(
                    id: item.id,
                    name: item.title,
                    initialIdea: item.summary,
                    kind: overlay?.kind ?? ProjectKind.inferred(from: item.type),
                    stage: overlay?.stage ?? .brief,
                    createdAt: item.createdAt
                )
            }

            let localInspirationsByID = Dictionary(uniqueKeysWithValues: inspirations.map { ($0.id, $0) })
            inspirations = remoteInspirations.items.map { item in
                let overlay = localInspirationsByID[item.id]
                return InspirationCapture(
                    id: item.id,
                    transcription: item.content,
                    pawnQAs: overlay?.pawnQAs ?? [],
                    bilibiliPack: overlay?.bilibiliPack,
                    projectID: item.projects.first?.id,
                    privacy: overlay?.privacy ?? .privateOnly,
                    createdAt: item.createdAt,
                    isDemoFallback: false
                )
            }
            persist()
            persistInspirations()
        } catch {
            syncErrorMessage = error.localizedDescription
        }
    }

    func advance(_ projectID: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        let nextStage: ProjectStage
        switch projects[index].stage {
        case .brief: nextStage = .creating
        case .creating: nextStage = .review
        case .review: nextStage = .approved
        case .approved: nextStage = .settled
        case .settled: return
        }
        projects[index].stage = nextStage
        persist()
    }

    func conversation(for projectID: UUID) -> PawnConversation? {
        pawnConversations.first { $0.projectID == projectID }
    }

    func remoteConversationID(for projectID: UUID) -> UUID? {
        remoteConversationIDs[projectID]
    }

    func setRemoteConversationID(_ conversationID: UUID, for projectID: UUID) {
        remoteConversationIDs[projectID] = conversationID
        persistRemoteConversationIDs()
    }

    func removeRemoteConversationID(for projectID: UUID) {
        remoteConversationIDs.removeValue(forKey: projectID)
        persistRemoteConversationIDs()
    }

    private func persistRemoteConversationIDs() {
        if let data = try? JSONEncoder().encode(remoteConversationIDs) {
            defaults.set(data, forKey: remoteConversationIDsKey)
        }
    }

    func ensureConversation(for project: CreatorProject) {
        guard conversation(for: project.id) == nil else { return }

        pawnConversations.append(
            PawnConversation(
                id: UUID(),
                projectID: project.id,
                messages: [
                    PawnMessage(
                        id: UUID(),
                        role: .pawn,
                        text: "我们从“\(project.initialIdea)”开始。你现在最想推进哪一部分？",
                        createdAt: .now,
                        isComplete: true
                    )
                ],
                attachments: [],
                updatedAt: .now
            )
        )
        persistPawnConversations()
    }

    func sendCreatorMessage(_ text: String, projectID: UUID) {
        appendMessage(text, role: .creator, isComplete: true, projectID: projectID)
    }

    @discardableResult
    func beginPawnMessage(projectID: UUID) -> UUID? {
        appendMessage("", role: .pawn, isComplete: false, projectID: projectID)
    }

    func updatePawnMessage(_ messageID: UUID, text: String, isComplete: Bool, projectID: UUID) {
        guard let conversationIndex = pawnConversations.firstIndex(where: { $0.projectID == projectID }),
              let messageIndex = pawnConversations[conversationIndex].messages.firstIndex(where: { $0.id == messageID }) else {
            return
        }

        pawnConversations[conversationIndex].messages[messageIndex].text = text
        pawnConversations[conversationIndex].messages[messageIndex].isComplete = isComplete
        pawnConversations[conversationIndex].updatedAt = .now
        persistPawnConversations()
    }

    func removeMessage(_ messageID: UUID, projectID: UUID) {
        guard let index = pawnConversations.firstIndex(where: { $0.projectID == projectID }) else { return }
        pawnConversations[index].messages.removeAll { $0.id == messageID }
        pawnConversations[index].updatedAt = .now
        persistPawnConversations()
    }

    func addAttachment(displayName: String, projectID: UUID) {
        guard let index = pawnConversations.firstIndex(where: { $0.projectID == projectID }) else { return }
        pawnConversations[index].attachments.append(
            PawnAttachment(id: UUID(), displayName: displayName, importedAt: .now)
        )
        pawnConversations[index].updatedAt = .now
        persistPawnConversations()
    }

    @discardableResult
    private func appendMessage(
        _ text: String,
        role: PawnMessage.Role,
        isComplete: Bool,
        projectID: UUID
    ) -> UUID? {
        guard let index = pawnConversations.firstIndex(where: { $0.projectID == projectID }) else { return nil }
        let message = PawnMessage(
            id: UUID(),
            role: role,
            text: text,
            createdAt: .now,
            isComplete: isComplete
        )
        pawnConversations[index].messages.append(message)
        pawnConversations[index].updatedAt = .now
        persistPawnConversations()
        return message.id
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func persistPawnConversations() {
        guard let data = try? JSONEncoder().encode(pawnConversations) else { return }
        defaults.set(data, forKey: pawnConversationsStorageKey)
    }

    // MARK: - Inspirations

    @discardableResult
    func addInspiration(
        transcription: String,
        pawnQAs: [PawnQA] = [],
        bilibiliPack: BilibiliPack? = nil,
        projectID: UUID? = nil,
        privacy: InspirationPrivacy = .privateOnly,
        isDemoFallback: Bool = false
    ) -> InspirationCapture {
        let capture = InspirationCapture(
            id: UUID(),
            transcription: transcription,
            pawnQAs: pawnQAs,
            bilibiliPack: bilibiliPack,
            projectID: projectID,
            privacy: privacy,
            createdAt: .now,
            isDemoFallback: isDemoFallback
        )
        inspirations.insert(capture, at: 0)
        persistInspirations()
        return capture
    }

    @discardableResult
    func addInspiration(
        transcription: String,
        pawnQAs: [PawnQA] = [],
        bilibiliPack: BilibiliPack? = nil,
        projectID: UUID? = nil,
        privacy: InspirationPrivacy = .privateOnly,
        isDemoFallback: Bool = false,
        sourceType: InspirationSourceType = .voice,
        accessToken: String?
    ) async throws -> InspirationCapture {
        guard let accessToken else {
            return addInspiration(
                transcription: transcription,
                pawnQAs: pawnQAs,
                bilibiliPack: bilibiliPack,
                projectID: projectID,
                privacy: privacy,
                isDemoFallback: isDemoFallback
            )
        }

        let remote = try await InspirationAPI.create(
            accessToken: accessToken,
            content: transcription,
            sourceType: sourceType,
            projectIDs: projectID.map { [$0] } ?? []
        )
        let capture = InspirationCapture(
            id: remote.id,
            transcription: remote.content,
            pawnQAs: pawnQAs,
            bilibiliPack: bilibiliPack,
            projectID: remote.projects.first?.id,
            privacy: privacy,
            createdAt: remote.createdAt,
            isDemoFallback: isDemoFallback
        )
        inspirations.removeAll { $0.id == capture.id }
        inspirations.insert(capture, at: 0)
        persistInspirations()
        return capture
    }

    func deleteInspiration(_ id: UUID) {
        inspirations.removeAll { $0.id == id }
        persistInspirations()
    }

    func deleteInspiration(_ id: UUID, accessToken: String?) async throws {
        if let accessToken {
            try await InspirationAPI.delete(id, accessToken: accessToken)
        }
        deleteInspiration(id)
    }

    func assignInspiration(_ id: UUID, toProject projectID: UUID) {
        guard let index = inspirations.firstIndex(where: { $0.id == id }) else { return }
        inspirations[index].projectID = projectID
        persistInspirations()
    }

    func assignInspiration(_ id: UUID, toProject projectID: UUID, accessToken: String?) async throws {
        if let accessToken {
            _ = try await InspirationAPI.update(
                id,
                accessToken: accessToken,
                projectIDs: [projectID]
            )
        }
        assignInspiration(id, toProject: projectID)
    }

    func updateInspirationPrivacy(_ id: UUID, privacy: InspirationPrivacy) {
        guard let index = inspirations.firstIndex(where: { $0.id == id }) else { return }
        inspirations[index].privacy = privacy
        persistInspirations()
    }

    func resetDemoData() {
        inspirations = [.demo()]
        projects = [.demo]
        pawnConversations = []
        persist()
        persistPawnConversations()
        persistInspirations()
    }

    private func persistInspirations() {
        guard let data = try? JSONEncoder().encode(inspirations) else { return }
        defaults.set(data, forKey: inspirationsStorageKey)
    }
}