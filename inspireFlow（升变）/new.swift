//
//  new.swift
//  inspireFlow
//
//  Created by 叶文峰 on 2026/7/23.
//

import SwiftUI

struct NewProjectView: View {
    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var session: AppSession

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @FocusState
    private var focusedField: Field?

    @State private var projectName: String
    @State private var initialIdea: String
    @State private var selectedContentType: ProjectContentType
    @State private var selectedGoal: ProjectGoal
    @State private var selectedKind: ProjectKind
    @State private var isShowingSuccess = false
    @State private var successFeedbackTrigger = 0
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var isDraftGenerating = false
    @State private var draftError: String?

    private let maximumProjectNameLength = 40
    private let maximumIdeaLength = 500

    init(
        projectName: String = "",
        initialIdea: String = "",
        selectedContentType: ProjectContentType = .video,
        selectedGoal: ProjectGoal = .outline,
        selectedKind: ProjectKind = .personal
    ) {
        _projectName = State(initialValue: projectName)
        _initialIdea = State(initialValue: initialIdea)
        _selectedContentType = State(
            initialValue: selectedContentType
        )
        _selectedGoal = State(initialValue: selectedGoal)
        _selectedKind = State(initialValue: selectedKind)
    }

    var body: some View {
        NewProjectBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    introductionSection

                    projectNameSection

                    initialIdeaSection

                    if !session.isDemoMode && !normalizedProjectName.isEmpty && !initialIdea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        pawnDraftSection
                    }

                    contentTypeSection

                    goalSection

                    projectKindSection

                    createButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("新建项目")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("创建") {
                    createProject()
                }
                .fontWeight(.semibold)
                .foregroundStyle(
                    canCreate
                        ? Color.white
                        : Color.white.opacity(0.35)
                )
                .disabled(!canCreate || isSaving)
                .accessibilityHint(
                    canCreate
                        ? "创建当前项目"
                        : "请先填写项目名称"
                )
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("完成") {
                    focusedField = nil
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert(
            "项目已创建",
            isPresented: $isShowingSuccess
        ) {
            Button("开始创作") {
                dismiss()
            }
        } message: {
            Text(session.isDemoMode
                ? "项目已保存到本机，PAWN 可以从这里继续维护创作上下文。"
                : "项目已同步到云端，PAWN 可以从这里继续维护创作上下文。")
        }
        .sensoryFeedback(
            .success,
            trigger: successFeedbackTrigger
        )
        .alert("无法创建项目", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(saveError ?? "请稍后重试。")
        }
    }

    private var normalizedProjectName: String {
        projectName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var pawnDraftSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PAWN 协助")
                .font(.headline)
                .foregroundStyle(.white)

            if draftError != nil {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(draftError ?? "")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("重试") {
                        draftError = nil
                        generateDraft()
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
            } else {
                Button {
                    generateDraft()
                } label: {
                    HStack {
                        if isDraftGenerating { ProgressView().tint(.black) }
                        Text("让 PAWN 完善这个想法")
                        Spacer()
                        Image(systemName: "sparkles")
                    }
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(isDraftGenerating)
            }
        }
    }

    private var canCreate: Bool {
        !normalizedProjectName.isEmpty
    }

    private var introductionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("从一个想法开始")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(
                "告诉 PAWN 你想创作什么，稍后可以继续补充细节。"
            )
            .font(.subheadline)
            .foregroundStyle(Color.white.opacity(0.58))
            .lineSpacing(3)
        }
        .padding(.top, 8)
    }

    private var projectNameSection: some View {
        NewProjectSection(
            title: "项目名称",
            detail: "必填"
        ) {
            NewProjectCard {
                VStack(alignment: .leading, spacing: 10) {
                    TextField(
                        "例如：无屏创作的一天",
                        text: $projectName
                    )
                    .focused($focusedField, equals: .projectName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .initialIdea
                    }
                    .onChange(of: projectName) { _, newValue in
                        guard newValue.count
                                > maximumProjectNameLength else {
                            return
                        }

                        projectName = String(
                            newValue.prefix(
                                maximumProjectNameLength
                            )
                        )
                    }
                    .accessibilityLabel("项目名称")
                    .accessibilityHint("输入新项目的名称")

                    HStack {
                        Text("给项目一个容易识别的名字")
                            .font(.caption)
                            .foregroundStyle(
                                Color.white.opacity(0.42)
                            )

                        Spacer()

                        Text(
                            "\(projectName.count)/\(maximumProjectNameLength)"
                        )
                        .font(
                            .caption2
                                .monospacedDigit()
                                .weight(.medium)
                        )
                        .foregroundStyle(
                            Color.white.opacity(0.38)
                        )
                    }
                }
            }
        }
    }

    private var initialIdeaSection: some View {
        NewProjectSection(
            title: "初始想法",
            detail: "选填"
        ) {
            NewProjectCard {
                VStack(alignment: .leading, spacing: 10) {
                    ZStack(alignment: .topLeading) {
                        if initialIdea.isEmpty {
                            Text(
                                "简单描述主题、灵感来源或你希望表达的内容……"
                            )
                            .font(.body)
                            .foregroundStyle(
                                Color.white.opacity(0.32)
                            )
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                        }

                        TextEditor(text: $initialIdea)
                            .focused(
                                $focusedField,
                                equals: .initialIdea
                            )
                            .font(.body)
                            .foregroundStyle(.white)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                            .onChange(
                                of: initialIdea
                            ) { _, newValue in
                                guard newValue.count
                                        > maximumIdeaLength else {
                                    return
                                }

                                initialIdea = String(
                                    newValue.prefix(
                                        maximumIdeaLength
                                    )
                                )
                            }
                            .accessibilityLabel("初始想法")
                            .accessibilityHint(
                                "描述项目主题、灵感来源或表达目标"
                            )
                    }

                    HStack {
                        Text("PAWN 会根据这段内容开始协作")
                            .font(.caption)
                            .foregroundStyle(
                                Color.white.opacity(0.42)
                            )

                        Spacer()

                        Text(
                            "\(initialIdea.count)/\(maximumIdeaLength)"
                        )
                        .font(
                            .caption2
                                .monospacedDigit()
                                .weight(.medium)
                        )
                        .foregroundStyle(
                            Color.white.opacity(0.38)
                        )
                    }
                }
            }
        }
    }

    private var contentTypeSection: some View {
        NewProjectSection(
            title: "内容类型",
            detail: selectedContentType.title
        ) {
            LazyVGrid(
                columns: selectionColumns,
                spacing: 10
            ) {
                ForEach(ProjectContentType.allCases) { type in
                    SelectionButton(
                        title: type.title,
                        symbol: type.symbol,
                        isSelected: selectedContentType == type
                    ) {
                        updateSelection {
                            selectedContentType = type
                        }
                    }
                }
            }
        }
    }

    private var goalSection: some View {
        NewProjectSection(
            title: "创作目标",
            detail: selectedGoal.title
        ) {
            LazyVGrid(
                columns: selectionColumns,
                spacing: 10
            ) {
                ForEach(ProjectGoal.allCases) { goal in
                    SelectionButton(
                        title: goal.title,
                        symbol: goal.symbol,
                        isSelected: selectedGoal == goal
                    ) {
                        updateSelection {
                            selectedGoal = goal
                        }
                    }
                }
            }
        }
    }

    private var projectKindSection: some View {
        NewProjectSection(
            title: "项目类型",
            detail: selectedKind.title
        ) {
            Picker("项目类型", selection: $selectedKind) {
                ForEach(ProjectKind.allCases) { kind in
                    Text(kind.title)
                        .tag(kind)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var createButton: some View {
        Button {
            createProject()
        } label: {
            Label(
                "创建项目",
                systemImage: "plus"
            )
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Color.white,
                in: RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
            )
        }
        .buttonStyle(
            NewProjectPressableButtonStyle(
                reduceMotion: reduceMotion
            )
        )
        .disabled(!canCreate || isSaving)
        .opacity(canCreate && !isSaving ? 1 : 0.34)
        .accessibilityHint(
            canCreate
                ? "创建项目并返回创作页面"
                : "请先填写项目名称"
        )
    }

    private var selectionColumns: [GridItem] {
        [
            GridItem(
                .flexible(),
                spacing: 10
            ),
            GridItem(
                .flexible(),
                spacing: 10
            )
        ]
    }

    private func updateSelection(
        _ changes: () -> Void
    ) {
        if reduceMotion {
            changes()
        } else {
            withAnimation(
                .easeOut(duration: 0.16)
            ) {
                changes()
            }
        }
    }

    private func generateDraft() {
        guard !initialIdea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let accessToken = session.accessToken else { return }
        isDraftGenerating = true
        draftError = nil
        Task {
            do {
                let draft = try await ProjectAPI.draft(
                    description: initialIdea,
                    accessToken: accessToken
                )
                projectName = draft.title
                selectedContentType = ProjectContentType.allCases.first { $0.title == draft.type } ?? .video
                if draft.summary.contains("大纲") || draft.summary.contains("框架") {
                    selectedGoal = .outline
                } else if draft.summary.contains("脚本") {
                    selectedGoal = .script
                } else {
                    selectedGoal = .outline
                }
                initialIdea = draft.summary
                Haptics.success()
                isDraftGenerating = false
            } catch {
                draftError = error.localizedDescription
                isDraftGenerating = false
                Haptics.error()
            }
        }
    }

    private func createProject() {
        guard canCreate, !isSaving else {
            focusedField = .projectName
            return
        }

        projectName = normalizedProjectName
        focusedField = nil
        isSaving = true
        Task {
            do {
                let idea = initialIdea.trimmingCharacters(in: .whitespacesAndNewlines)
                let projectSummary = idea.isEmpty
                    ? "创作目标：\(selectedGoal.title)"
                    : "\(idea)\n创作目标：\(selectedGoal.title)"
                _ = try await appStore.createProject(
                    name: projectName,
                    initialIdea: projectSummary,
                    kind: selectedKind,
                    contentType: selectedContentType.title,
                    audience: "内容创作者",
                    accessToken: session.accessToken
                )
                isSaving = false
                successFeedbackTrigger += 1
                isShowingSuccess = true
            } catch {
                isSaving = false
                saveError = error.localizedDescription
                Haptics.error()
            }
        }
    }
}

// MARK: - Form Components

private struct NewProjectSection<Content: View>: View {
    let title: String
    let detail: String
    let content: Content

    init(
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(
                        Color.white.opacity(0.42)
                    )
            }

            content
        }
    }
}

private struct NewProjectCard<Content: View>: View {
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
            .background(
                Color.white.opacity(0.055),
                in: cardShape
            )
            .overlay {
                cardShape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.17),
                                Color.white.opacity(0.045)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: 22,
            style: .continuous
        )
    }
}

private struct SelectionButton: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))

                Text(title)
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                }
            }
            .foregroundStyle(
                isSelected
                    ? Color.black
                    : Color.white.opacity(0.68)
            )
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                isSelected
                    ? Color.white
                    : Color.white.opacity(0.055),
                in: RoundedRectangle(
                    cornerRadius: 15,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 15,
                    style: .continuous
                )
                .strokeBorder(
                    isSelected
                        ? Color.white
                        : Color.white.opacity(0.1),
                    lineWidth: 0.8
                )
            }
        }
        .buttonStyle(
            NewProjectPressableButtonStyle(
                reduceMotion: reduceMotion
            )
        )
        .accessibilityLabel(title)
        .accessibilityValue(
            isSelected
                ? "已选择"
                : "未选择"
        )
        .accessibilityAddTraits(
            isSelected
                ? .isSelected
                : []
        )
    }
}

private struct NewProjectBackground<Content: View>: View {
    let content: Content

    init(
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color(
                red: 0.018,
                green: 0.018,
                blue: 0.022
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.white.opacity(0.055),
                    Color.white.opacity(0.012),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 460
            )
            .ignoresSafeArea()

            content
        }
    }
}

private struct NewProjectPressableButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(
        configuration: Configuration
    ) -> some View {
        configuration.label
            .scaleEffect(
                reduceMotion || !configuration.isPressed
                    ? 1
                    : 0.97
            )
            .opacity(
                configuration.isPressed
                    ? 0.84
                    : 1
            )
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

// MARK: - Supporting Types

private enum Field: Hashable {
    case projectName
    case initialIdea
}

enum ProjectContentType: String, CaseIterable, Identifiable {
    case video
    case article
    case podcast
    case other

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .video:
            return "视频"

        case .article:
            return "图文"

        case .podcast:
            return "播客"

        case .other:
            return "其他"
        }
    }

    var symbol: String {
        switch self {
        case .video:
            return "video.fill"

        case .article:
            return "doc.text.fill"

        case .podcast:
            return "waveform"

        case .other:
            return "square.grid.2x2.fill"
        }
    }
}

enum ProjectGoal: String, CaseIterable, Identifiable {
    case capture
    case outline
    case script
    case custom

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .capture:
            return "记录灵感"

        case .outline:
            return "生成大纲"

        case .script:
            return "完成脚本"

        case .custom:
            return "自定义"
        }
    }

    var symbol: String {
        switch self {
        case .capture:
            return "sparkles"

        case .outline:
            return "list.bullet"

        case .script:
            return "text.quote"

        case .custom:
            return "slider.horizontal.3"
        }
    }
}

// MARK: - Previews

#Preview("New Project - Empty") {
    NavigationStack {
        NewProjectView()
    }
    .preferredColorScheme(.dark)
    .environmentObject(AppStore())
    .environmentObject(AppSession())
}

#Preview("New Project - Filled") {
    NavigationStack {
        NewProjectView(
            projectName: "无屏创作的一天",
            initialIdea: "记录如何用戒指和耳机捕捉现场灵感，并把它逐步整理成可以拍摄的视频。",
            selectedContentType: .video,
            selectedGoal: .outline,
            selectedKind: .personal
        )
    }
    .preferredColorScheme(.dark)
    .environmentObject(AppStore())
    .environmentObject(AppSession())
}
