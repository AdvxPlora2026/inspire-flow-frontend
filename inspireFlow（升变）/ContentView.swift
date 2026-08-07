//
//  ContentView.swift
//  inspireFlow
//
//  Created by 叶文峰 on 2026/7/23.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .inspiration

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                InspirationDemoView()
            }
            .tabItem {
                Label(
                    AppTab.inspiration.title,
                    systemImage: AppTab.inspiration.symbol
                )
            }
            .tag(AppTab.inspiration)

            NavigationStack {
                CreationDemoView()
            }
            .tabItem {
                Label(
                    AppTab.creation.title,
                    systemImage: AppTab.creation.symbol
                )
            }
            .tag(AppTab.creation)

            NavigationStack {
                PawnWorkspaceView()
            }
            .tabItem {
                Label(
                    AppTab.collaboration.title,
                    systemImage: AppTab.collaboration.symbol
                )
            }
            .tag(AppTab.collaboration)

            NavigationStack {
                ProfileDemoView()
            }
            .tabItem {
                Label(
                    AppTab.profile.title,
                    systemImage: AppTab.profile.symbol
                )
            }
            .tag(AppTab.profile)
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Inspiration

struct InspirationDemoView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isListening = false
    @State private var privacyLevel: PrivacyLevel = .privateOnly
    @State private var capturePhase: CapturePhase = .ready
    @State private var questionIndex = 0

    private let productionQuestions = [
        ProductionQuestion(
            prompt: "这条视频最想讲给谁看？".localized,
            answer: "第一次尝试无屏创作的 B 站创作者".localized
        ),
        ProductionQuestion(
            prompt: "你希望它是什么形式？".localized,
            answer: "60 秒现场竖屏短视频".localized
        ),
        ProductionQuestion(
            prompt: "最重要的开场画面是什么？".localized,
            answer: "创作者正在拍摄，却突然冒出一个灵感".localized
        )
    ]

    var body: some View {
        ShengbianBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    captureButton

                    captureWorkflowSection

                    privacySection

                    recentIdeasSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("接住灵感".localized)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                } label: {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("PAWN")
            }
        }
    }

    private var captureButton: some View {
        Button {
            handleCaptureButton()
        } label: {
            VStack(spacing: 24) {
                HStack {
                    Label(
                        isListening ? "PAWN 正在聆听".localized : "PAWN 已准备好".localized,
                        systemImage: isListening ? "waveform" : "ear"
                    )
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(
                        isListening
                            ? ShengbianColors.listening
                            : ShengbianColors.secondaryText
                    )

                    Spacer()

                    Text(isListening ? "正在记录".localized : "本地私密".localized)
                        .font(ShengbianTypography.technical)
                        .foregroundStyle(ShengbianColors.tertiaryText)
                }

                ZStack {
                    ForEach([1.0, 0.7], id: \.self) { scale in
                        Circle()
                            .strokeBorder(
                                isListening
                                    ? ShengbianColors.listening.opacity(0.15 + (1 - scale) * 0.15)
                                    : ShengbianColors.primaryText.opacity(0.08),
                                lineWidth: 1
                            )
                            .frame(width: 156 * scale, height: 156 * scale)
                    }

                    Image(systemName: isListening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(
                            isListening
                                ? ShengbianColors.listening
                                : ShengbianColors.inverseText
                        )
                        .frame(width: 68, height: 68)
                        .background(
                            isListening
                                ? ShengbianColors.listening.opacity(0.14)
                                : ShengbianColors.primaryAction,
                            in: Circle()
                        )
                }
                .frame(height: 156)

                CaptureWaveform(isActive: isListening)
                    .frame(maxWidth: 250)

                VStack(spacing: 5) {
                    Text(isListening ? "轻点结束并继续".localized : "轻点开始说话".localized)
                        .font(ShengbianTypography.headline)
                    Text(isListening ? "随后进入三轮 PAWN 追问".localized : "也可以双击 Zilo 戒指唤醒".localized)
                        .font(ShengbianTypography.caption)
                        .foregroundStyle(ShengbianColors.secondaryText)
                }
            }
            .foregroundStyle(ShengbianColors.primaryText)
            .padding(ShengbianMetrics.cardPadding)
            .background(.regularMaterial, in: captureShape)
            .background(ShengbianColors.glassTintStrong, in: captureShape)
            .overlay {
                captureShape.strokeBorder(
                    isListening
                        ? ShengbianColors.listening.opacity(0.5)
                        : ShengbianColors.glassBorder,
                    lineWidth: isListening ? 1.25 : 0.75
                )
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityValue(
            isListening
                ? "正在捕捉".localized
                : "尚未开始".localized
        )
    }

    private var captureShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: ShengbianMetrics.cardRadius, style: .continuous)
    }

    @ViewBuilder
    private var captureWorkflowSection: some View {
        switch capturePhase {
        case .ready, .listening:
            EmptyView()
        case .questioning:
            GlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        ShengbianStatusLabel(
                            title: "PAWN 追问",
                            symbol: "sparkles",
                            state: .neutral
                        )

                        Spacer()

                        Text("\(questionIndex + 1) / \(productionQuestions.count)")
                            .font(ShengbianTypography.technical)
                            .foregroundStyle(ShengbianColors.secondaryText)
                            .contentTransition(.numericText())
                    }

                    Text(productionQuestions[questionIndex].prompt)
                        .font(ShengbianTypography.title2)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        answerCurrentQuestion()
                    } label: {
                        Label(
                            productionQuestions[questionIndex].answer,
                            systemImage: "waveform"
                        )
                        .font(ShengbianTypography.bodyEmphasized)
                        .foregroundStyle(ShengbianColors.inverseText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            ShengbianColors.primaryAction,
                            in: RoundedRectangle(cornerRadius: ShengbianMetrics.controlRadius, style: .continuous)
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityHint("模拟通过耳机回答当前问题".localized)
                }
            }
        case .generated:
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Label("创作方案已生成".localized, systemImage: "checkmark.circle.fill")
                        .font(.headline)

                    ResultLine(label: "标题".localized, value: "我用一枚戒指，接住了差点消失的灵感".localized)
                    ResultLine(label: "3 秒钩子".localized, value: "最好的创作工具，也许根本没有屏幕。".localized)
                    ResultLine(label: "结构".localized, value: "灵感丢失 → 戒指唤醒 → 耳机追问 → PAWN 成片".localized)
                    ResultLine(label: "拍摄".localized, value: "现场走拍、戒指特写、耳机反馈、方案结果页".localized)

                    Button("重新演示".localized) {
                        resetCaptureDemo()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
            }
        }
    }

    private func handleCaptureButton() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.84)) {
            if isListening {
                isListening = false
                capturePhase = .questioning
                questionIndex = 0
            } else {
                isListening = true
                capturePhase = .listening
            }
        }
    }

    private func answerCurrentQuestion() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            if questionIndex < productionQuestions.count - 1 {
                questionIndex += 1
            } else {
                capturePhase = .generated
            }
        }
    }

    private func resetCaptureDemo() {
        isListening = false
        questionIndex = 0
        capturePhase = .ready
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "隐私级别".localized,
                detail: "戒指手势可切换".localized
            )

            HStack(spacing: 8) {
                ForEach(PrivacyLevel.allCases) { level in
                    PrivacyLevelButton(
                        level: level,
                        isSelected: privacyLevel == level
                    ) {
                        privacyLevel = level
                    }
                }
            }
        }
    }

    private var recentIdeasSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "最近灵感".localized,
                detail: "查看全部".localized
            )

            IdeaRow(
                title: "为什么城市夜晚适合记录声音？".localized,
                detail: "刚刚 · 已追问 3 轮".localized,
                symbol: "waveform"
            )

            IdeaRow(
                title: "用一天测试无屏创作工作流".localized,
                detail: "昨天 · 已生成视频大纲".localized,
                symbol: "wand.and.stars"
            )

            IdeaRow(
                title: "活动现场的十个临场拍摄技巧".localized,
                detail: "周一 · 私密".localized,
                symbol: "lock.fill"
            )
        }
    }
}

private struct CaptureWaveform: View {
    let isActive: Bool

    private let levels: [CGFloat] = [10, 18, 28, 15, 34, 22, 13, 26, 18, 31, 14, 22]

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                Capsule()
                    .fill(isActive ? ShengbianColors.listening : ShengbianColors.tertiaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: isActive ? level : 4)
                    .animation(
                        .easeInOut(duration: 0.24).delay(Double(index) * 0.018),
                        value: isActive
                    )
            }
        }
        .frame(height: 38)
        .accessibilityHidden(true)
    }
}

private struct PrivacyLevelButton: View {
    let level: PrivacyLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(
                level.title,
                systemImage: level.symbol
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(
                isSelected
                    ? Color.black
                    : Color.white.opacity(0.52)
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background {
                Capsule()
                    .fill(
                        isSelected
                            ? Color.white
                            : Color.white.opacity(0.055)
                    )
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        isSelected
                            ? Color.white
                            : Color.white.opacity(0.1),
                        lineWidth: 0.8
                    )
            }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Creation

private struct CreationDemoView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var selectedFilter: ProjectFilter = .all
    @State private var isCreatingProject = false

    private var filteredProjects: [CreatorProject] {
        appStore.projects.filter { selectedFilter.includes($0.stage) }
    }

    var body: some View {
        DemoPageBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    filterPicker

                    projectsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("创作".localized)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreatingProject = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("新建创作".localized)
            }
        }
        .navigationDestination(isPresented: $isCreatingProject) {
            NewProjectView()
        }
    }

    private var filterPicker: some View {
        Picker(
            "项目筛选".localized,
            selection: $selectedFilter
        ) {
            ForEach(ProjectFilter.allCases) { filter in
                Text(filter.title)
                    .tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var projectsSection: some View {
        if filteredProjects.isEmpty {
            ContentUnavailableView(
                "暂无项目".localized,
                systemImage: "square.stack.3d.up.slash",
                description: Text("新建项目后，PAWN 会在这里持续维护创作状态。".localized)
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "项目".localized,
                    detail: String(format: "%d 个".localized, filteredProjects.count)
                )

                ForEach(filteredProjects) { project in
                    ProjectRow(project: project) {
                        appStore.advance(project.id)
                    }
                }
            }
        }
    }
}

// MARK: - PAWN Workspace

struct PawnWorkspaceView: View {
    @State private var draftReply = ""

    @State private var messages: [DemoMessage] = [
        DemoMessage(
            text: "我已经整理了《无屏创作的一天》的初版大纲。你希望开头更偏故事感，还是直接展示戒指唤醒？".localized,
            isAgent: true
        ),
        DemoMessage(
            text: "先用一个活动现场突然有灵感的场景开头，然后再展示戒指。".localized,
            isAgent: false
        ),
        DemoMessage(
            text: "明白。我会把开头改成 15 秒的现场钩子，并保留同一个项目上下文。".localized,
            isAgent: true
        )
    ]

    var body: some View {
        ShengbianBackground {
            VStack(spacing: 0) {
                messageList

                composer
            }
        }
        .navigationTitle("PAWN")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("PAWN")
                        .font(.headline)

                    Text("上下文已同步".localized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                TaskContextCard()

                ForEach(messages) { message in
                    MessageBubble(message: message)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            Button {
            } label: {
                Image(systemName: "plus")
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .tint(.white)

            TextField(
                "回复 PAWN…".localized,
                text: $draftReply
            )
            .textFieldStyle(.plain)
            .padding(.horizontal, 15)
            .frame(height: 42)
            .background(
                .thinMaterial,
                in: RoundedRectangle(cornerRadius: ShengbianMetrics.controlRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: ShengbianMetrics.controlRadius, style: .continuous)
                    .strokeBorder(
                        ShengbianColors.glassBorder,
                        lineWidth: 0.8
                    )
            }

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 38, height: 38)
                    .background(
                        draftReply.isEmpty
                            ? Color.white.opacity(0.35)
                            : Color.white,
                        in: Circle()
                    )
            }
            .disabled(draftReply.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func sendMessage() {
        let content = draftReply.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !content.isEmpty else {
            return
        }

        messages.append(
            DemoMessage(
                text: content,
                isAgent: false
            )
        )

        draftReply = ""
    }
}

// MARK: - Profile

private struct ProfileDemoView: View {
    @State private var localEncryptionEnabled = true

    var body: some View {
        DemoPageBackground {
            List {
                profileSection

                deviceSection

                privacySettingsSection
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("我的".localized)
        .navigationBarTitleDisplayMode(.large)
    }

    private var profileSection: some View {
        Section {
            HStack(spacing: 16) {
                Text("P")
                    .font(.title2.bold())
                    .foregroundStyle(.black)
                    .frame(width: 58, height: 58)
                    .background(Color.white, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("PAWN Creator")
                        .font(.headline)

                    Text("12 条灵感 · 3 个创作项目".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var deviceSection: some View {
        Section("设备".localized) {
            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Zilo Whisper")

                    Text("已连接 · 电量 84%".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "circle.hexagongrid.fill")
                    .foregroundStyle(.green)
            }

            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text("viaim 耳机")

                    Text("已连接 · 麦克风可用".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "headphones")
                    .foregroundStyle(.white)
            }
        }
    }

    private var privacySettingsSection: some View {
        Section {
            Toggle(isOn: $localEncryptionEnabled) {
                Label(
                    "本地加密".localized,
                    systemImage: "lock.fill"
                )
            }
            .tint(.blue)

            NavigationLink {
                ContentUnavailableView(
                    "暂无商业凭证".localized,
                    systemImage: "checkmark.seal",
                    description: Text("作品提交并完成链上结算后，可在这里查看对应版本的公开凭证。".localized)
                )
            } label: {
                Label(
                    "商业任务凭证".localized,
                    systemImage: "checkmark.seal.fill"
                )
            }
        } header: {
            Text("记忆与授权".localized)
        } footer: {
            Text(
                "原始内容只保存在本地；链上只记录商业任务的版本摘要、授权和结算状态。".localized
            )
        }
    }
}

// MARK: - Native Tab Configuration

private enum AppTab: Hashable {
    case inspiration
    case creation
    case collaboration
    case profile

    var title: String {
        switch self {
        case .inspiration:
            return "灵感".localized

        case .creation:
            return "创作".localized

        case .collaboration:
            return "PAWN"

        case .profile:
            return "我的".localized
        }
    }

    var symbol: String {
        switch self {
        case .inspiration:
            return "sparkles"

        case .creation:
            return "wand.and.stars"

        case .collaboration:
            return "bubble.left.and.bubble.right"

        case .profile:
            return "person.crop.circle"
        }
    }
}

// MARK: - Reusable Components

private struct DemoPageBackground<Content: View>: View {
    let content: Content

    init(
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
    }

    var body: some View {
        ShengbianBackground { content }
    }
}

private struct GlassCard<Content: View>: View {
    let content: Content

    init(
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(.thinMaterial, in: cardShape)
            .background(ShengbianColors.glassTint, in: cardShape)
            .overlay {
                cardShape
                    .strokeBorder(
                        ShengbianColors.glassBorder,
                        lineWidth: 0.8
                    )
            }
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: ShengbianMetrics.cardRadius,
            style: .continuous
        )
    }
}

private struct SectionHeader: View {
    let title: String
    let detail: String

    var body: some View {
        HStack {
            Text(title.localized)
                .font(.headline)

            Spacer()

            Text(detail.localized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct IdeaRow: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(
                        .system(
                            size: 17,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        ShengbianColors.glassTintStrong,
                        in: RoundedRectangle(
                            cornerRadius: ShengbianMetrics.controlRadius,
                            style: .continuous
                        )
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(title.localized)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Text(detail.localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct ResultChip: View {
    let title: String
    let symbol: String
    let isReady: Bool

    var body: some View {
        VStack(spacing: 7) {
            Image(
                systemName: isReady
                    ? "checkmark.circle.fill"
                    : symbol
            )
            .foregroundStyle(
                isReady
                    ? Color.green
                    : Color.secondary
            )

            Text(title.localized)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            ShengbianColors.glassTint,
            in: RoundedRectangle(
                cornerRadius: ShengbianMetrics.controlRadius,
                style: .continuous
            )
        )
    }
}

private struct ResultLine: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.localized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value.localized)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ProjectRow: View {
    let project: CreatorProject
    let advance: () -> Void

    private var progress: Double {
        project.stage.progress
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(project.name.localized)
                            .font(.subheadline.weight(.semibold))

                        Text(project.stage.title.localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(Int(progress * 100))%")
                        .font(
                            .caption
                                .monospacedDigit()
                                .weight(.semibold)
                        )
                        .foregroundStyle(
                            progress >= 1
                                ? Color.green
                                : Color.white
                        )
                }

                ProgressView(value: progress)
                    .tint(
                        progress >= 1
                            ? Color.green
                            : Color.white
                    )

                HStack {
                    Label(
                        project.kind.title.localized,
                        systemImage: project.kind == .commercial
                            ? "briefcase.fill"
                            : "person.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Spacer()

                    if project.stage != .settled {
                        Button(project.stage.actionTitle.localized, action: advance)
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.bordered)
                            .tint(.white)
                    }
                }
            }
        }
    }
}

private struct TaskContextCard: View {
    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: "link")
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Color.white.opacity(0.08),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("无屏创作的一天".localized)
                        .font(.subheadline.weight(.semibold))

                    Text("上下文已同步 · 4 轮对话".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("进行中".localized)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(ShengbianColors.primaryText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        ShengbianColors.glassTintStrong,
                        in: Capsule()
                    )
            }
        }
    }
}

private struct MessageBubble: View {
    let message: DemoMessage

    var body: some View {
        HStack {
            if !message.isAgent {
                Spacer(minLength: 48)
            }

            VStack(alignment: .leading, spacing: 6) {
                if message.isAgent {
                    Label(
                        "PAWN",
                        systemImage: "sparkles"
                    )
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                }

                Text((try? AttributedString(markdown: message.text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(message.text))
                    .font(.subheadline)
                    .lineSpacing(3)
                    .foregroundStyle(
                        message.isAgent
                            ? Color.white
                            : Color.black
                    )
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background(
                message.isAgent
                    ? Color.white.opacity(0.07)
                    : Color.white,
                in: RoundedRectangle(
                    cornerRadius: ShengbianMetrics.controlRadius,
                    style: .continuous
                )
            )

            if message.isAgent {
                Spacer(minLength: 48)
            }
        }
    }
}

private struct PressableButtonStyle: ButtonStyle {
    func makeBody(
        configuration: Configuration
    ) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed
                    ? 0.97
                    : 1
            )
            .opacity(
                configuration.isPressed
                    ? 0.84
                    : 1
            )
            .animation(
                .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

// MARK: - Supporting Types

private struct DemoMessage: Identifiable {
    let id = UUID()
    let text: String
    let isAgent: Bool
}

private enum CapturePhase {
    case ready
    case listening
    case questioning
    case generated
}

private struct ProductionQuestion {
    let prompt: String
    let answer: String
}

private enum PrivacyLevel: String, CaseIterable, Identifiable {
    case privateOnly
    case projectMembers
    case publicContent

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .privateOnly:
            return "私密".localized

        case .projectMembers:
            return "项目成员".localized

        case .publicContent:
            return "公开".localized
        }
    }

    var symbol: String {
        switch self {
        case .privateOnly:
            return "lock.fill"

        case .projectMembers:
            return "person.2.fill"

        case .publicContent:
            return "globe.asia.australia.fill"
        }
    }
}

private enum ProjectFilter: String, CaseIterable, Identifiable {
    case all
    case creating
    case completed

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .all:
            return "全部".localized

        case .creating:
            return "创作中".localized

        case .completed:
            return "已完成".localized
        }
    }

    func includes(_ stage: ProjectStage) -> Bool {
        switch self {
        case .all:
            return true
        case .creating:
            return stage != .settled
        case .completed:
            return stage == .settled
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppStore())
}
