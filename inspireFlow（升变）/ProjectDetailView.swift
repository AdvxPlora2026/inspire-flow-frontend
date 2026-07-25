import SwiftUI

struct ProjectDetailView: View {
    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var ring: RingManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let projectID: UUID

    private var project: CreatorProject? {
        appStore.projects.first { $0.id == projectID }
    }

    private var linkedInspirations: [InspirationCapture] {
        appStore.inspirations.filter { $0.projectID == projectID }
    }

    var body: some View {
        ShengbianBackground {
            if let project {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        projectHeader(project)
                        progressSection(project)
                        if project.kind == .commercial {
                            chainSection
                        }
                        goalSection(project)
                        capturesSection(project)
                        artifactSection(project)
                        activitySection(project)
                    }
                    .padding(.horizontal, ShengbianMetrics.pageMargin)
                    .padding(.bottom, 40)
                }
            } else {
                ContentUnavailableView(
                    "项目不可用",
                    systemImage: "exclamationmark.folder",
                    description: Text("它可能已在其他位置被移除。")
                )
            }
        }
        .navigationTitle(project?.name ?? "项目")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func projectHeader(_ project: CreatorProject) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label(
                    project.kind.title,
                    systemImage: project.kind == .commercial ? "briefcase.fill" : "person.fill"
                )
                .font(ShengbianTypography.caption)
                .foregroundStyle(ShengbianColors.secondaryText)

                Spacer()

                Text(project.stage.title)
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.primaryText)
            }

            Text(project.name)
                .font(ShengbianTypography.display)
                .fixedSize(horizontal: false, vertical: true)

            if project.kind == .commercial && !session.isDemoMode {
                CommercialTaskView(projectID: project.id, projectName: project.name, existingTaskID: project.commercialTaskID)
            } else if project.stage != .settled {
                Button {
                    advanceStage(project)
                } label: {
                    HStack(spacing: 10) {
                        Text(project.stage.actionTitle)
                            .font(ShengbianTypography.headline)
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .foregroundStyle(ShengbianColors.inverseText)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: ShengbianMetrics.minimumControlHeight)
                    .background(
                        ShengbianColors.primaryAction,
                        in: RoundedRectangle(cornerRadius: ShengbianMetrics.controlRadius, style: .continuous)
                    )
                }
                .shengbianPressable(reduceMotion: reduceMotion)
                .accessibilityHint("将项目推进到下一阶段")
            } else {
                Label("项目已完成", systemImage: "checkmark.circle.fill")
                    .font(ShengbianTypography.headline)
                    .foregroundStyle(ShengbianColors.primaryText)
                    .frame(maxWidth: .infinity, minHeight: ShengbianMetrics.minimumControlHeight)
                    .background(
                        ShengbianColors.glassTintStrong,
                        in: RoundedRectangle(cornerRadius: ShengbianMetrics.controlRadius, style: .continuous)
                    )
            }
        }
        .padding(.top, 12)
    }

    private func advanceStage(_ project: CreatorProject) {
        let reachesSettled = project.stage == .approved
        withAnimation(ShengbianMotion.maybe(.standardSpring, reduceMotion)) {
            appStore.advance(project.id)
        }
        if reachesSettled {
            Haptics.impact(.rigid)
        }
        Haptics.success()
    }

    private func progressSection(_ project: CreatorProject) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ShengbianSectionHeader(title: "项目进度", detail: "\(Int(project.stage.progress * 100))%")

            VStack(spacing: 14) {
                ProgressView(value: project.stage.progress)
                    .tint(ShengbianColors.primaryText)
                    .accessibilityLabel("项目进度")
                    .accessibilityValue("百分之 \(Int(project.stage.progress * 100))")

                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(ProjectStage.allCases.enumerated()), id: \.element) { index, stage in
                        stageMarker(
                            stage,
                            index: index,
                            currentIndex: ProjectStage.allCases.firstIndex(of: project.stage) ?? 0
                        )
                    }
                }
            }
            .padding(ShengbianMetrics.cardPadding)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ShengbianMetrics.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: ShengbianMetrics.cardRadius, style: .continuous)
                    .strokeBorder(ShengbianColors.glassBorder)
            }
        }
    }

    private var chainSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ShengbianSectionHeader(title: "Injective 商业凭证", detail: "链上")

            ShengbianGlassCard(emphasis: .prominent) {
                VStack(alignment: .leading, spacing: 16) {
                    Label("商业任务链路已由后端提供", systemImage: "checkmark.seal.fill")
                        .font(ShengbianTypography.bodyEmphasized)

                    HStack(spacing: 0) {
                        chainStep("预算托管", symbol: "lock.shield")
                        chainStep("作品存证", symbol: "doc.badge.ellipsis")
                        chainStep("授权确认", symbol: "signature")
                        chainStep("自动结算", symbol: "arrow.triangle.branch")
                    }

                    Text("当前 App 尚未绑定商业任务 ID，因此不会显示交易哈希或声称已经上链。完成接口接入后，这里将展示网络、交易状态与区块浏览器链接。")
                        .font(ShengbianTypography.caption)
                        .foregroundStyle(ShengbianColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func chainStep(_ title: String, symbol: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(ShengbianColors.secondaryText)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func stageMarker(_ stage: ProjectStage, index: Int, currentIndex: Int) -> some View {
        let isComplete = index < currentIndex
        let isCurrent = index == currentIndex

        return VStack(spacing: 7) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : isCurrent ? "circle.inset.filled" : "circle")
                .font(.caption)
                .foregroundStyle(
                    isComplete || isCurrent
                        ? ShengbianColors.primaryText
                        : ShengbianColors.tertiaryText
                )
                .symbolEffect(.bounce, value: currentIndex)
                .contentTransition(.symbolEffect(.replace))

            Text(stage.title)
                .font(.system(size: 9, weight: isCurrent ? .semibold : .regular))
                .foregroundStyle(isCurrent ? ShengbianColors.primaryText : ShengbianColors.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stage.title)，\(isComplete ? "已完成" : isCurrent ? "当前阶段" : "未开始")")
    }

    private func goalSection(_ project: CreatorProject) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ShengbianSectionHeader(title: "创作目标", detail: nil)

            ShengbianGlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "quote.opening")
                        .font(.title3)
                        .foregroundStyle(ShengbianColors.secondaryText)

                    Text(project.initialIdea.isEmpty ? "还没有写下创作目标。" : project.initialIdea)
                        .font(ShengbianTypography.bodyEmphasized)
                        .fixedSize(horizontal: false, vertical: true)

                    Label(
                        "创建于 \(project.createdAt.formatted(date: .abbreviated, time: .omitted))",
                        systemImage: "calendar"
                    )
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.secondaryText)
                }
            }
        }
    }

    private func artifactSection(_ project: CreatorProject) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ShengbianSectionHeader(title: "创作台", detail: "6 个入口")

            NavigationLink {
                ProjectPawnWorkspaceView(projectID: project.id)
            } label: {
                workspaceRow(
                    title: "与 PAWN 继续",
                    detail: "围绕这个项目推进上下文",
                    symbol: "sparkles",
                    action: "打开"
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                MindMapView(projectID: project.id)
            } label: {
                workspaceRow(
                    title: "脑图",
                    detail: "用力导向图查看项目结构",
                    symbol: "point.3.connected.trianglepath.dotted",
                    action: "查看"
                )
            }
            .buttonStyle(.plain)

            ForEach(ProjectArtifactKind.allCases) { artifact in
                NavigationLink {
                    ProjectArtifactView(project: project, artifact: artifact)
                } label: {
                    workspaceRow(
                        title: artifact.title,
                        detail: artifact.detail,
                        symbol: artifact.symbol,
                        action: "开始"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func workspaceRow(title: String, detail: String, symbol: String, action: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.headline)
                .frame(width: 42, height: 42)
                .background(ShengbianColors.glassTintStrong, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ShengbianTypography.bodyEmphasized)
                Text(detail)
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.secondaryText)
            }

            Spacer(minLength: 8)

            Text(action)
                .font(ShengbianTypography.caption)
                .foregroundStyle(ShengbianColors.secondaryText)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(ShengbianColors.tertiaryText)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ShengbianMetrics.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ShengbianMetrics.cardRadius, style: .continuous)
                .strokeBorder(ShengbianColors.glassBorder)
        }
    }

    private func activitySection(_ project: CreatorProject) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ShengbianSectionHeader(title: "最近活动", detail: nil)

            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "clock")
                    .foregroundStyle(ShengbianColors.secondaryText)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text("项目处于“\(project.stage.title)”")
                        .font(ShengbianTypography.bodyEmphasized)
                    Text("当前仅记录项目阶段；详细活动将在产生创作内容后显示。")
                        .font(ShengbianTypography.caption)
                        .foregroundStyle(ShengbianColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func capturesSection(_ project: CreatorProject) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ShengbianSectionHeader(
                title: "关联灵感",
                detail: linkedInspirations.isEmpty ? nil : "\(linkedInspirations.count) 条"
            )

            if linkedInspirations.isEmpty {
                ShengbianGlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("还没有关联灵感", systemImage: "waveform")
                            .font(ShengbianTypography.subheadline)
                            .foregroundStyle(ShengbianColors.secondaryText)

                        Button {
                            ring.presentCapture(projectID: project.id)
                        } label: {
                            Label("现在捕捉", systemImage: "mic.fill")
                                .font(ShengbianTypography.caption)
                                .foregroundStyle(ShengbianColors.inverseText)
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                                .background(
                                    ShengbianColors.primaryAction,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                ForEach(linkedInspirations.prefix(3)) { inspiration in
                    NavigationLink {
                        InspirationDetailView(inspirationID: inspiration.id)
                    } label: {
                        captureRow(inspiration)
                    }
                    .buttonStyle(.plain)
                }

                if linkedInspirations.count > 3 {
                    Text("还有 \(linkedInspirations.count - 3) 条，前往「灵感」查看全部")
                        .font(ShengbianTypography.caption)
                        .foregroundStyle(ShengbianColors.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private func captureRow(_ inspiration: InspirationCapture) -> some View {
        HStack(spacing: 14) {
            Image(systemName: inspiration.bilibiliPack != nil ? "wand.and.stars" : "waveform")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(ShengbianColors.glassTintStrong, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .foregroundStyle(ShengbianColors.primaryText)

            VStack(alignment: .leading, spacing: 4) {
                Text(inspiration.transcription.isEmpty ? "（无文字）" : inspiration.transcription)
                    .font(ShengbianTypography.subheadline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(inspiration.createdAt.formatted(.relative(presentation: .named)))
                        .font(ShengbianTypography.caption)
                        .foregroundStyle(ShengbianColors.tertiaryText)

                    if inspiration.bilibiliPack != nil {
                        Text("·").font(ShengbianTypography.caption).foregroundStyle(ShengbianColors.tertiaryText)
                        Text("已生成方案")
                            .font(ShengbianTypography.caption)
                            .foregroundStyle(ShengbianColors.success)
                    }

                    if inspiration.isDemoFallback {
                        Text("·").font(ShengbianTypography.caption).foregroundStyle(ShengbianColors.tertiaryText)
                        Text("演示")
                            .font(ShengbianTypography.technical)
                            .foregroundStyle(ShengbianColors.warning)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(ShengbianColors.tertiaryText)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ShengbianMetrics.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ShengbianMetrics.cardRadius, style: .continuous)
                .strokeBorder(ShengbianColors.glassBorder)
        }
    }
}


private enum ProjectArtifactKind: String, CaseIterable, Identifiable {
    case outline
    case storyboard
    case script
    case teleprompter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .outline: "视频大纲"
        case .storyboard: "分镜"
        case .script: "提词稿"
        case .teleprompter: "提词拍摄"
        }
    }

    var detail: String {
        switch self {
        case .outline: "组织章节、钩子与叙事节奏"
        case .storyboard: "规划镜头、画面与声音"
        case .script: "写作旁白、对白与画面提示"
        case .teleprompter: "进入低干扰全屏提词模式"
        }
    }

    var symbol: String {
        switch self {
        case .outline: "list.bullet.rectangle"
        case .storyboard: "rectangle.split.3x1"
        case .script: "doc.text"
        case .teleprompter: "text.viewfinder"
        }
    }

    func content(from pack: BilibiliPack) -> String {
        switch self {
        case .outline: pack.outline
        case .storyboard: pack.shotList
        case .script: "\(pack.hook)\n\n\(pack.outline)"
        case .teleprompter: "\(pack.hook)\n\n\(pack.outline)\n\n\(pack.shotList)"
        }
    }

    func pawnPrompt(for project: CreatorProject) -> String {
        switch self {
        case .outline:
            "请为《\(project.name)》生成可直接编辑的视频大纲，包含开场钩子、章节顺序和每段目标。"
        case .storyboard:
            "请为《\(project.name)》生成可拍摄的分镜清单，逐镜写出画面、台词、时长和拍摄提示。"
        case .script:
            "请为《\(project.name)》生成可直接朗读的提词稿，保留自然口语节奏和段落停顿。"
        case .teleprompter:
            "请为《\(project.name)》整理一份适合提词拍摄的完整口播稿。"
        }
    }
}

private struct ProjectArtifactView: View {
    @EnvironmentObject private var appStore: AppStore
    let project: CreatorProject
    let artifact: ProjectArtifactKind

    private var packs: [BilibiliPack] {
        appStore.inspirations
            .filter { $0.projectID == project.id }
            .compactMap(\.bilibiliPack)
            .filter { !artifact.content(from: $0).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        ShengbianBackground {
            Group {
                if packs.isEmpty {
                    ContentUnavailableView {
                        Label(artifact.title, systemImage: artifact.symbol)
                    } description: {
                        Text("“\(project.name)”还没有这项内容。")
                    } actions: {
                        NavigationLink {
                            ProjectPawnWorkspaceView(
                                projectID: project.id,
                                initialDraft: artifact.pawnPrompt(for: project)
                            )
                        } label: {
                            Label("交给 PAWN 生成", systemImage: "sparkles")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white)
                        .foregroundStyle(.black)
                    }
                } else if artifact == .teleprompter {
                    VStack(spacing: 18) {
                        ShengbianGlassCard(emphasis: .prominent) {
                            Label("已找到 \(packs.count) 份项目提词内容", systemImage: "text.viewfinder")
                                .font(ShengbianTypography.bodyEmphasized)
                        }

                        NavigationLink {
                            TeleprompterView(projectID: project.id)
                        } label: {
                            Label("进入全屏提词", systemImage: "play.fill")
                                .font(ShengbianTypography.headline)
                                .foregroundStyle(ShengbianColors.inverseText)
                                .frame(maxWidth: .infinity, minHeight: ShengbianMetrics.minimumControlHeight)
                                .background(ShengbianColors.primaryAction, in: RoundedRectangle(cornerRadius: ShengbianMetrics.controlRadius))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(ShengbianMetrics.pageMargin)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(packs.enumerated()), id: \.offset) { index, pack in
                                ShengbianGlassCard(emphasis: index == 0 ? .prominent : .standard) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(pack.title)
                                            .font(ShengbianTypography.bodyEmphasized)
                                        Text(artifact.content(from: pack))
                                            .font(ShengbianTypography.body)
                                            .foregroundStyle(ShengbianColors.secondaryText)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }

                            NavigationLink {
                                ProjectPawnWorkspaceView(
                                    projectID: project.id,
                                    initialDraft: "请继续优化《\(project.name)》的\(artifact.title)，并说明具体改动。"
                                )
                            } label: {
                                Label("让 PAWN 继续优化", systemImage: "sparkles")
                                    .font(ShengbianTypography.headline)
                                    .foregroundStyle(ShengbianColors.inverseText)
                                    .frame(maxWidth: .infinity, minHeight: ShengbianMetrics.minimumControlHeight)
                                    .background(ShengbianColors.primaryAction, in: RoundedRectangle(cornerRadius: ShengbianMetrics.controlRadius))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(ShengbianMetrics.pageMargin)
                    }
                }
            }
        }
        .navigationTitle(artifact.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}