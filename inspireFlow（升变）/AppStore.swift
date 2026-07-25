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
    var commercialTaskID: UUID?
    var createdAt: Date

    static let demo = CreatorProject(
        id: UUID(),
        name: "AdventureX 创作幕后",
        initialIdea: "记录随手用语音捕捉灵感，再由 PAWN 完成 B 站创作方案的全过程。",
        kind: .commercial,
        stage: .creating,
        commercialTaskID: nil,
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

            // ---- MERGE projects: remote items with local overrides, + local-only orphans ----
            let localProjectsByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
            var remoteIDs = Set<UUID>()
            var mergedProjects: [CreatorProject] = remoteProjects.items.map { item in
                remoteIDs.insert(item.id)
                let overlay = localProjectsByID[item.id]
                return CreatorProject(
                    id: item.id,
                    name: overlay?.name ?? item.title,
                    initialIdea: overlay?.initialIdea ?? item.summary,
                    kind: overlay?.kind ?? ProjectKind.inferred(from: item.type),
                    stage: overlay?.stage ?? .brief,
                    commercialTaskID: overlay?.commercialTaskID,
                    createdAt: item.createdAt
                )
            }
            // Keep local-only projects that haven't been pushed yet
            for local in projects where !remoteIDs.contains(local.id) {
                mergedProjects.append(local)
            }
            projects = mergedProjects

            // ---- MERGE inspirations: remote items with local overrides, + local-only orphans ----
            let localInspirationsByID = Dictionary(uniqueKeysWithValues: inspirations.map { ($0.id, $0) })
            var remoteInspIDs = Set<UUID>()
            var mergedInspirations: [InspirationCapture] = remoteInspirations.items.map { item in
                remoteInspIDs.insert(item.id)
                let overlay = localInspirationsByID[item.id]
                return InspirationCapture(
                    id: item.id,
                    transcription: overlay?.transcription ?? item.content,
                    pawnQAs: overlay?.pawnQAs ?? [],
                    bilibiliPack: overlay?.bilibiliPack,
                    projectID: overlay?.projectID ?? item.projects.first?.id,
                    privacy: overlay?.privacy ?? .privateOnly,
                    createdAt: item.createdAt,
                    isDemoFallback: false
                )
            }
            // Keep local-only inspirations
            for local in inspirations where !remoteInspIDs.contains(local.id) {
                mergedInspirations.append(local)
            }
            inspirations = mergedInspirations

            persist()
            persistInspirations()
        } catch {
            syncErrorMessage = error.localizedDescription
        }
    }

    func advance(_ projectID: UUID, accessToken: String? = nil) {
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

    func setCommercialTaskID(for projectID: UUID, taskID: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        projects[index].commercialTaskID = taskID
        persist()
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
            sourceType: sourceType == .agent ? .manual : sourceType,
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
            try await InspirationAPI.addProjectLink(id, projectID: projectID, accessToken: accessToken)
        }
        assignInspiration(id, toProject: projectID)
    }

    func updateInspirationPrivacy(_ id: UUID, privacy: InspirationPrivacy, accessToken: String? = nil) {
        guard let index = inspirations.firstIndex(where: { $0.id == id }) else { return }
        inspirations[index].privacy = privacy
        persistInspirations()

        if let accessToken {
            Task {
                try? await InspirationAPI.update(id, accessToken: accessToken)
            }
        }
    }

    func resetDemoData() {
        inspirations = [.demo()]
        projects = [.demo]
        pawnConversations = []
        persist()
        persistPawnConversations()
        persistInspirations()
    }

    /// Seed a rich set of demo data covering multiple project types, stages,
    /// linked inspirations with PAWN Q&As & Bilibili packs, and full conversations.
    func seedRichDemoData() {
        let now = Date()
        let day = 86_400.0

        // ── Project 1: Personal · creating ──────────────────────────────
        let p1 = CreatorProject(
            id: UUID(),
            name: "30天Vlog挑战",
            initialIdea: "每天拍一条1分钟生活Vlog，记录创作日常与灵感捕捉流程，做成系列内容。",
            kind: .personal, stage: .creating, commercialTaskID: nil,
            createdAt: now.addingTimeInterval(-14 * day)
        )
        let p1i1 = InspirationCapture(
            id: UUID(), transcription: "今天在路上想到一个好点子：用第一人称视角拍一天，从起床到睡觉，不加任何旁白，纯靠画面和字幕讲故事。观众会觉得像自己在过这一天。",
            pawnQAs: [
                PawnQA(id: UUID(), question: "观众看完这一天，最可能记住哪个画面？", answer: "凌晨四点起床时窗外还没亮的天色，和晚上一个人坐在电脑前的剪影"),
                PawnQA(id: UUID(), question: "这一天的节奏怎么安排？", answer: "按时间线自然推进，每个时间段选一个代表性动作，避免流水账"),
                PawnQA(id: UUID(), question: "配乐和色调的基调？", answer: "冷色调为主，白天偏灰蓝，晚上暖黄台灯形成对比")
            ],
            bilibiliPack: BilibiliPack(title: "我花了一天时间，只拍了一个问题——创作者的一天到底值不值得羡慕", hook: "早上4:00，我醒了。但这不是励志故事。", outline: "晨间（4:00-8:00）孤独的灵感时间 → 白天（9:00-18:00）奔波拍摄 → 夜晚（19:00-2:00）一个人剪辑", shotList: "窗外天色变化延时、键盘特写、走路跟拍、台灯剪影、屏幕反光中的人脸"),
            projectID: p1.id, privacy: .publicContent, createdAt: now.addingTimeInterval(-7 * day), isDemoFallback: true
        )
        let p1i2 = InspirationCapture(
            id: UUID(), transcription: "要不要做一个'用戒指触发灵感'的真实对比视频？一边用手机打字记录，一边用戒指双击录音，看哪个更快、更完整地保留当时的想法。",
            pawnQAs: [
                PawnQA(id: UUID(), question: "对比实验的评分维度是什么？", answer: "速度（触发到开始记录的时间）、完整度（事后能回忆起多少细节）、自然度（是否打断当时的活动）"),
                PawnQA(id: UUID(), question: "拍摄环境选在哪里？", answer: "咖啡厅、地铁站、公园散步——三个场景各测一次，增加说服力"),
                PawnQA(id: UUID(), question: "怎么让观众参与进来？", answer: "结尾设一个投票：你习惯用什么方式记灵感？A.手机备忘录 B.语音 C.手写 D.不记")
            ],
            bilibiliPack: BilibiliPack(title: "录音 vs 打字 vs 戒指，我实测了三种记灵感方式——差距比想象中大", hook: "这个画面只持续了3秒。如果我掏手机，它已经没了。", outline: "问题引入（灵感丢失的痛）→ 三种方式对比实验 → 数据对比表 → 戒指 vs 手机的体验差异 → 结尾投票", shotList: "边走边打字vs边走边录音的分屏、戒指双击特写、三个场景计时对比表格动画、观众投票界面"),
            projectID: p1.id, privacy: .publicContent, createdAt: now.addingTimeInterval(-3 * day), isDemoFallback: true
        )

        // ── Project 2: Personal · review ─────────────────────────────────
        let p2 = CreatorProject(
            id: UUID(),
            name: "科技测评：M4 MacBook Pro 真实体验",
            initialIdea: "从创作者视角深度评测 M4 MacBook Pro，重点关注视频剪辑、AI 推理和多任务场景的性能表现。",
            kind: .personal, stage: .review, commercialTaskID: nil,
            createdAt: now.addingTimeInterval(-21 * day)
        )
        let p2i1 = InspirationCapture(
            id: UUID(), transcription: "刚跑完Davinci Resolve的4K渲染对比测试，M4 Max比M3 Max快了约30%，但发热也更明显。这个数据值得单独出一期视频。",
            pawnQAs: [
                PawnQA(id: UUID(), question: "对比测试的数据可视化怎么做？", answer: "用柱状图+温度热力图叠加，渲染时间用柱状图，温度曲线用折线图，放在同一个时间轴上"),
                PawnQA(id: UUID(), question: "目标观众的技术水平？", answer: "中高级创作者，需要告诉他们实际工作流中的差异，而不是跑分数字"),
                PawnQA(id: UUID(), question: "有没有反直觉的发现？", answer: "风扇噪音在轻负载时反而比M3大，但满载时更安静——这个反直觉的点值得单独强调")
            ],
            bilibiliPack: BilibiliPack(title: "M4 MacBook Pro 深度评测：创作者的真实感受，不是跑分", hook: "我花了一周时间用它剪了10条视频。有一些事，跑分不会告诉你。", outline: "开箱（30s）→ 渲染对比（重点）→ 散热与噪音（反直觉发现）→ AI 推理实测 → 最终建议", shotList: "实拍工作台+MacBook、渲染进度条特写、热成像画面、DaVinci时间线对比、最终评分表格"),
            projectID: p2.id, privacy: .projectMembers, createdAt: now.addingTimeInterval(-10 * day), isDemoFallback: true
        )
        let p2i2 = InspirationCapture(
            id: UUID(), transcription: "发现一个有意思的细节：M4的神经网络引擎在背景虚化处理上比M3快了接近两倍，这个在视频会议和直播场景里很有用。可以结合AI能力单独做一期。",
            pawnQAs: [
                PawnQA(id: UUID(), question: "这一期的角度和上一期的区别？", answer: "上一期偏性能，这一期偏场景——不讲参数，讲'你的实际体验会变成什么样'"),
                PawnQA(id: UUID(), question: "需要什么对比参照？", answer: "同价位Windows创作本（比如幻16），在相同场景下对比，给观众一个决策参考"),
                PawnQA(id: UUID(), question: "要不要测游戏？", answer: "提一嘴但不展开——MacBook的游戏短板大家都知道，但M4确实能跑一些3A了，可以放30秒彩蛋")
            ],
            bilibiliPack: BilibiliPack(title: "M4 MacBook 的 AI 能力有多强？我试了直播、抠图、视频降噪", hook: "如果把M4的AI引擎单独拉出来看，它可能是今年最被低估的升级。", outline: "AI引擎简介 → 直播背景虚化实测 → 视频降噪对比 → 抠图速度对比 → 彩蛋：3A游戏帧数", shotList: "OBS直播界面、降噪前后对比分屏、抠图进度条、游戏帧数监控、最后彩蛋表情"),
            projectID: p2.id, privacy: .projectMembers, createdAt: now.addingTimeInterval(-5 * day), isDemoFallback: true
        )
        let p2i3 = InspirationCapture(
            id: UUID(), transcription: "观众评论里有人问：和台式机比怎么样？要不要出一个'移动工作站 vs 台式工作站'的终极对比？这个选题可以做。",
            pawnQAs: [
                PawnQA(id: UUID(), question: "对比维度怎么定？", answer: "便携性、性能上限、扩展性、价格——四个维度给不同的权重，因为目标需求不同"),
                PawnQA(id: UUID(), question: "这个视频适合什么节奏？", answer: "快速节奏，不要拖——5分钟内把四个维度的结论给清楚，细节放评论区")
            ],
            bilibiliPack: nil,
            projectID: p2.id, privacy: .privateOnly, createdAt: now.addingTimeInterval(-1 * day), isDemoFallback: true
        )

        // ── Project 3: Commercial · creating (chain escrow_funded) ────────
        let p3 = CreatorProject(
            id: UUID(),
            name: "品牌联名推广｜声阔 Liberty 5 Pro",
            initialIdea: "品牌 Brief：展示 Liberty 5 Pro 的 AI 降噪和空间音频功能，时长 3-5 分钟，目标人群为 18-35 岁通勤上班族。预算 5000，截止 8 月 25 日。",
            kind: .commercial, stage: .creating, commercialTaskID: UUID(),
            createdAt: now.addingTimeInterval(-10 * day)
        )
        let p3i1 = InspirationCapture(
            id: UUID(), transcription: "通勤场景的选择——地铁、公交、走路，三种场景下的降噪体验差异很大。地铁最有故事感，因为噪音最大、对比最强。",
            pawnQAs: [
                PawnQA(id: UUID(), question: "品牌的核心卖点怎么自然植入？", answer: "不用硬说'降噪很强'，而是让观众通过镜头感受——打开降噪前地铁的嘈杂 vs 打开后突然安静，这个对比本身就是最好的广告"),
                PawnQA(id: UUID(), question: "BGM 和音效的设计？", answer: "前半段用嘈杂环境音，中段突然切入一首空间音频适配的歌曲，让观众同时感受到降噪+音质的变化"),
                PawnQA(id: UUID(), question: "演员/出镜人？", answer: "创作者自己出镜更真实——找一个每天通勤的朋友，真实记录而不是表演")
            ],
            bilibiliPack: BilibiliPack(title: "我戴着这款耳机通勤了一周，在地铁上发生了意想不到的事", hook: "地铁进站的那一瞬间，我什么也听不见了——不对，是除了音乐什么也听不见。", outline: "通勤痛点（30s）→ 开箱（20s）→ 地铁降噪实测（核心1分半）→ 空间音频体验（1分）→ 总结与购买链接", shotList: "地铁进站慢动作、降噪开关对比画面、耳机电量/App界面、通勤路线地图动画、产品360°展示"),
            projectID: p3.id, privacy: .projectMembers, createdAt: now.addingTimeInterval(-5 * day), isDemoFallback: true
        )
        let p3i2 = InspirationCapture(
            id: UUID(), transcription: "品牌方反馈说想加一段空间音频的演示——可以让观众用耳机听出声音的方位变化，这个如果用双耳录音效果最好。",
            pawnQAs: [
                PawnQA(id: UUID(), question: "双耳录音的设备和后期？", answer: "需要一个人头录音设备或者专门的3D麦克风，后期不需要特殊处理，空间音频耳机直接支持回放"),
                PawnQA(id: UUID(), question: "这个段落放在视频哪个位置？", answer: "放在降噪测试之后、总结之前——先用降噪证明实用性，再用空间音频展示技术亮点，逻辑上互补"),
                PawnQA(id: UUID(), question: "怎么告知观众这个段落的特殊性？", answer: "画面提示'请戴上耳机体验空间音频效果'，字幕+图标双重提示，确保手机外放用户也能理解")
            ],
            bilibiliPack: BilibiliPack(title: "戴上耳机！这段空间音频演示会让你怀疑声音从哪来的", hook: "接下来请你戴上耳机——因为等一下的声音，会从你意想不到的方向传来。", outline: "双耳录音简介（20s）→ 空间音频演示（1分）→ 声音方位逐个解析（40s）→ 与普通立体声的对比（30s）", shotList: "人头录音设备特写、方位指示动画（前/后/左/右/上）、耳机佩戴提示图标、声波雷达图、体验者表情反应"),
            projectID: p3.id, privacy: .projectMembers, createdAt: now.addingTimeInterval(-2 * day), isDemoFallback: true
        )

        // ── Project 4: Commercial · settled (completed chain) ─────────────
        let p4 = CreatorProject(
            id: UUID(),
            name: "新品发布会直播策划｜XREAL Air 3",
            initialIdea: "品牌委托：策划并执行一场 B 站直播发布会，介绍 XREAL Air 3 的升级亮点，时长 45 分钟，包含产品演示、嘉宾对谈和弹幕互动环节。预算 20000，已结算完成。",
            kind: .commercial, stage: .settled, commercialTaskID: UUID(),
            createdAt: now.addingTimeInterval(-30 * day)
        )
        let p4i1 = InspirationCapture(
            id: UUID(), transcription: "发布会开场不要用传统的'欢迎来到'——用一段 AR 效果的开场，让 XREAL Air 3 的虚拟屏幕直接出现在观众面前。这个想法来自上次看 WWDC 的 Vision Pro 演示。",
            pawnQAs: [
                PawnQA(id: UUID(), question: "AR 开场的技术实现方案？", answer: "用实拍+后期合成模拟 AR 效果，不需要真 AR 设备。摄像机位固定，后期叠加虚拟屏幕动画，与主播互动配合"),
                PawnQA(id: UUID(), question: "开场时长和节奏？", answer: "90秒内完成——前20秒环境建立，中间40秒AR展示核心功能（多屏协作、空间定位），最后30秒引入主播"),
                PawnQA(id: UUID(), question: "如果直播时 AR 合成出问题怎么办？", answer: "提前录制备用开场视频，直播时如果合成不稳定就切到备用视频，观众无感")
            ],
            bilibiliPack: BilibiliPack(title: "AR 视界开场｜XREAL Air 3 发布会直播全记录", hook: "欢迎来到我的视野——这是你从未见过的发布会开场。", outline: "AR开场(90s) → 产品升级亮点(10min) → 嘉宾体验对谈(15min) → 弹幕问答(10min) → 彩蛋与福利(5min)", shotList: "AR开场合成画面、产品360°展示、嘉宾佩戴体验特写、弹幕实时上屏、福利码特写"),
            projectID: p4.id, privacy: .publicContent, createdAt: now.addingTimeInterval(-20 * day), isDemoFallback: true
        )
        let p4i2 = InspirationCapture(
            id: UUID(), transcription: "弹幕互动环节很容易冷场——提前准备20个'伪弹幕'作为暖场，同时安排一个同事在后台筛选真实弹幕。关键是让嘉宾觉得是真实互动。",
            pawnQAs: [
                PawnQA(id: UUID(), question: "伪弹幕的内容方向？", answer: "50%产品相关问题（让嘉宾展示专业性）、30%趣味提问（增加娱乐性）、20%引导购买（铺垫后续转化）"),
                PawnQA(id: UUID(), question: "嘉宾对谈的节奏把控？", answer: "每轮问答不超过3分钟，留足够时间给弹幕。如果嘉宾话多，用'我们来看一下弹幕怎么说的'自然切入下一轮")
            ],
            bilibiliPack: nil,
            projectID: p4.id, privacy: .projectMembers, createdAt: now.addingTimeInterval(-15 * day), isDemoFallback: true
        )

        // ── Project 5: Commercial · brief (brand hasn't created chain) ────
        let p5 = CreatorProject(
            id: UUID(),
            name: "小红书种草企划｜无感记录生活好物",
            initialIdea: "品牌合作：为一款智能家居品牌策划小红书画册+短视频种草内容。主打'无感记录'概念——用 InspireFlow 戒指随手记录生活碎片，自然植入产品。预算 8000，待品牌方确认细节。",
            kind: .commercial, stage: .brief, commercialTaskID: nil,
            createdAt: now.addingTimeInterval(-3 * day)
        )
        let p5i1 = InspirationCapture(
            id: UUID(), transcription: "小红书的内容节奏和 B 站不一样——更短、更碎片化、更图文化。需要把 3-5 分钟的视频拆成 3-5 篇小红书笔记，每篇一个独立的小场景。",
            pawnQAs: [
                PawnQA(id: UUID(), question: "每篇笔记的结构怎么设计？", answer: "封面图（吸睛）+ 3-5张场景图 + 一段150字以内的体验文字 + 2-3个相关标签。最后一页统一放产品链接"),
                PawnQA(id: UUID(), question: "标题和封面的风格？", answer: "小红书风格关键词：氛围感、治愈、极简、真实。避免硬广感，用'被问爆了'、'终于找到了'这类口语化标题"),
                PawnQA(id: UUID(), question: "发布频率和时段？", answer: "一周3-4篇，分散在周二四六晚上7-9点（小红书流量高峰）。首篇选周六发布，数据会好一些")
            ],
            bilibiliPack: nil,
            projectID: p5.id, privacy: .projectMembers, createdAt: now.addingTimeInterval(-1 * day), isDemoFallback: true
        )

        // ══════════════════════════════════════════════════════════════════
        // Assemble
        projects = [p1, p2, p3, p4, p5]
        inspirations = [p1i1, p1i2, p2i1, p2i2, p2i3, p3i1, p3i2, p4i1, p4i2, p5i1]

        // Conversations for each project
        pawnConversations = [
            PawnConversation(id: UUID(), projectID: p1.id, messages: [
                PawnMessage(id: UUID(), role: .pawn, text: "我们从“\(p1.initialIdea)”开始。先聊聊第一天的主题？", createdAt: now.addingTimeInterval(-13 * day), isComplete: true),
                PawnMessage(id: UUID(), role: .creator, text: "第一天我想拍「我的创作台」——展示设备和工具，给观众一个背景，后面每天的 Vlog 就不用重复解释了。", createdAt: now.addingTimeInterval(-13 * day + 300), isComplete: true),
                PawnMessage(id: UUID(), role: .pawn, text: "好思路。展示创作台的时候可以顺便埋一个钩子：'这个戒指是我用来随时捕捉灵感的'，让观众对后面的内容产生好奇。", createdAt: now.addingTimeInterval(-13 * day + 600), isComplete: true),
                PawnMessage(id: UUID(), role: .creator, text: "那第15天的主题我还没想好，你有建议吗？", createdAt: now.addingTimeInterval(-5 * day), isComplete: true),
                PawnMessage(id: UUID(), role: .pawn, text: "第15天正好是作品中期——可以做一个「创作崩溃日记」：什么环节最难、怎么调整心态。观众喜欢真实的挣扎，这会增加账号的人味。", createdAt: now.addingTimeInterval(-5 * day + 300), isComplete: true),
            ], attachments: [], updatedAt: now.addingTimeInterval(-5 * day)),
            PawnConversation(id: UUID(), projectID: p2.id, messages: [
                PawnMessage(id: UUID(), role: .pawn, text: "M4 MacBook 的深度体验——你打算从哪个角度切入？性能、创作体验、还是性价比？", createdAt: now.addingTimeInterval(-20 * day), isComplete: true),
                PawnMessage(id: UUID(), role: .creator, text: "创作体验优先——我不想做硬件参数测评，想做'一个创作者用了一个月后的感受'。剪辑、调色、AI 工具这些实际场景的表现。", createdAt: now.addingTimeInterval(-20 * day + 360), isComplete: true),
                PawnMessage(id: UUID(), role: .pawn, text: "这是一个很好的差异化角度。大部分测评都在跑分，你从实际体验出发更容易建立信任。需要我先帮你列出几个测试场景吗？", createdAt: now.addingTimeInterval(-20 * day + 700), isComplete: true),
                PawnMessage(id: UUID(), role: .creator, text: "对，帮我把测试场景列出来。另外，散热和续航也是我非常想知道的两点。", createdAt: now.addingTimeInterval(-19 * day), isComplete: true),
                PawnMessage(id: UUID(), role: .pawn, text: "测试场景可以这样安排：1）4K ProRes 多轨剪辑 2）AI 降噪/抠图 3）编译大型项目 4）外接双 4K 显示器的表现 5）离电续航实测。散热单独做一个热成像对比。", createdAt: now.addingTimeInterval(-19 * day + 400), isComplete: true),
                PawnMessage(id: UUID(), role: .creator, text: "很好。评测基本完成了，现在进入最后的成片阶段。结论是：对于创作者来说，这次升级值得。", createdAt: now.addingTimeInterval(-2 * day), isComplete: true),
                PawnMessage(id: UUID(), role: .pawn, text: "祝贺！评测完成。需要我帮你整理一个发布 checklist 吗？包括标题、简介、标签和发布时段建议。", createdAt: now.addingTimeInterval(-2 * day + 350), isComplete: true),
            ], attachments: [PawnAttachment(id: UUID(), displayName: "M4评测数据.xlsx", importedAt: now.addingTimeInterval(-15 * day))], updatedAt: now.addingTimeInterval(-2 * day)),
            PawnConversation(id: UUID(), projectID: p3.id, messages: [
                PawnMessage(id: UUID(), role: .pawn, text: "声阔 Liberty 5 Pro 的 Brief 已经创建。我们先聊聊:你最想在视频里展示什么功能？", createdAt: now.addingTimeInterval(-9 * day), isComplete: true),
                PawnMessage(id: UUID(), role: .creator, text: "AI降噪和空间音频——这两个是品牌方最看重的卖点。我希望用一种自然的方式来展示，而不是念参数。", createdAt: now.addingTimeInterval(-9 * day + 300), isComplete: true),
                PawnMessage(id: UUID(), role: .pawn, text: "理解。可以试试「通勤路线实测」——带上耳机在不同环境切换，让观众通过画面和声音感受降噪效果。你平时的通勤路线是什么样的？", createdAt: now.addingTimeInterval(-9 * day + 650), isComplete: true),
                PawnMessage(id: UUID(), role: .creator, text: "我家到工作室要坐40分钟地铁，中间还要走15分钟路。地铁那段最适合展示降噪——噪音很大，对比很明显。", createdAt: now.addingTimeInterval(-8 * day), isComplete: true),
                PawnMessage(id: UUID(), role: .pawn, text: "完美。地铁段的拍摄计划：进站时保持降噪关闭（收录环境音），上车后打开降噪（瞬间安静），中间切换空间音频模式（让观众感受声场变化）。整个段落只需要3-4个镜头切换。需要我帮你写分镜吗？", createdAt: now.addingTimeInterval(-8 * day + 400), isComplete: true),
                PawnMessage(id: UUID(), role: .creator, text: "对，帮我把地铁这一段的分镜写出来。还有品牌方说要加空间音频演示，用双耳录音的方式来做。", createdAt: now.addingTimeInterval(-6 * day), isComplete: true),
                PawnMessage(id: UUID(), role: .pawn, text: "双耳录音需要人头录音设备。地铁段分镜：1）站台全景（环境音max）2）进站脚步跟拍 3）关门的瞬间切降噪ON（安静对比）4）车厢内近景（主播表情自然）5）空间音频App界面。你确认一下设备清单。", createdAt: now.addingTimeInterval(-6 * day + 450), isComplete: true),
            ], attachments: [PawnAttachment(id: UUID(), displayName: "品牌Brief.pdf", importedAt: now.addingTimeInterval(-9 * day)), PawnAttachment(id: UUID(), displayName: "地铁分镜表.md", importedAt: now.addingTimeInterval(-5 * day))], updatedAt: now.addingTimeInterval(-3 * day)),
            PawnConversation(id: UUID(), projectID: p4.id, messages: [
                PawnMessage(id: UUID(), role: .pawn, text: "XREAL Air 3 发布会——这个是大项目。我们先定框架：45分钟怎么分配？", createdAt: now.addingTimeInterval(-28 * day), isComplete: true),
                PawnMessage(id: UUID(), role: .creator, text: "开场 AR 秀（1-2min）+ 产品亮点（10min）+ 嘉宾对谈（15min）+ 弹幕互动（10min）+ 彩蛋和福利（5min）。你觉得这个分配合理吗？", createdAt: now.addingTimeInterval(-28 * day + 400), isComplete: true),
                PawnMessage(id: UUID(), role: .pawn, text: "分配合理。AR 开场是个很大胆的想法，但需要注意：直播中如果合成出问题怎么办？建议提前录好备用开场视频。另外嘉宾对谈15分钟可能偏长，控制在12分钟内更紧凑。", createdAt: now.addingTimeInterval(-28 * day + 800), isComplete: true),
                PawnMessage(id: UUID(), role: .creator, text: "发布会圆满成功！观众峰值破万，弹幕互动超过2000条。品牌方非常满意，已经在谈下一期深度合作了。", createdAt: now.addingTimeInterval(-7 * day), isComplete: true),
                PawnMessage(id: UUID(), role: .pawn, text: "太棒了！品牌方满意度高的话，可以建议他们把这场发布会的录播剪辑成精华版，作为品牌官方宣传素材复用。这也能成为你 Portfolio 里的一个漂亮案例。", createdAt: now.addingTimeInterval(-7 * day + 300), isComplete: true),
            ], attachments: [PawnAttachment(id: UUID(), displayName: "发布会流程.md", importedAt: now.addingTimeInterval(-25 * day)), PawnAttachment(id: UUID(), displayName: "嘉宾资料.pdf", importedAt: now.addingTimeInterval(-20 * day))], updatedAt: now.addingTimeInterval(-7 * day)),
            PawnConversation(id: UUID(), projectID: p5.id, messages: [
                PawnMessage(id: UUID(), role: .pawn, text: "小红书种草——这个平台的关键是「真实性」和「氛围感」。你打算用图文还是短视频为主？", createdAt: now.addingTimeInterval(-2 * day), isComplete: true),
                PawnMessage(id: UUID(), role: .creator, text: "图文+短视频混合——每个场景先用图文版发布，一周后补一条15-30秒的短视频作为回顾。这样覆盖两种内容消费习惯的用户。", createdAt: now.addingTimeInterval(-2 * day + 500), isComplete: true),
                PawnMessage(id: UUID(), role: .pawn, text: "好的，图文先行验证话题性，短视频做二次传播——这是一个很聪明的节奏。你的第一篇选题是什么场景？", createdAt: now.addingTimeInterval(-2 * day + 900), isComplete: true),
                PawnMessage(id: UUID(), role: .creator, text: "第一篇想拍「早晨的仪式感」——用戒指记录起床后的第一杯咖啡、打开窗帘、打开音乐的过程。在这个场景里自然地展示产品。", createdAt: now.addingTimeInterval(-1 * day), isComplete: true),
                PawnMessage(id: UUID(), role: .pawn, text: "仪式感题材在小红书上非常吃香。注意：封面图的光线要暖色调（日出后1小时内拍效果最好），文字配'被问爆了的早晨流程'或者'终于找到了早起的动力'这类标题。需要品牌方确认的是一周发布频率和产品链接格式。", createdAt: now.addingTimeInterval(-1 * day + 400), isComplete: true),
            ], attachments: [], updatedAt: now.addingTimeInterval(-1 * day)),
        ]

        persist()
        persistPawnConversations()
        persistInspirations()
    }

    private func persistInspirations() {
        guard let data = try? JSONEncoder().encode(inspirations) else { return }
        defaults.set(data, forKey: inspirationsStorageKey)
    }
}