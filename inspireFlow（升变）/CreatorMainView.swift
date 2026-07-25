import SwiftUI

struct CreatorMainView: View {
    @EnvironmentObject private var ring: RingManager
    @State private var selectedTab: CreatorTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { CreatorHomeView() }
                .tabItem { Label("首页", systemImage: "house.fill") }
                .tag(CreatorTab.home)

            NavigationStack { CreatorProjectsView() }
                .tabItem { Label("项目", systemImage: "square.stack.3d.up.fill") }
                .tag(CreatorTab.projects)

            NavigationStack { PawnProjectHubView() }
                .tabItem { Label("PAWN", systemImage: "sparkles") }
                .tag(CreatorTab.pawn)

            NavigationStack { AccountView() }
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(CreatorTab.account)
        }
        .tint(.white)
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .sheet(isPresented: $ring.isCapturePresented, onDismiss: {
            ring.clearCaptureContext()
        }) {
            InspirationRecordView(projectID: ring.captureProjectID)
        }
        .onReceive(ring.captureSignal) {
            // Lets a ring double-press/double-tap open capture from any tab,
            // not just while InspirationRecordView is already on screen.
            Haptics.impact(.medium)
            ring.presentCapture()
        }
    }

    private enum CreatorTab: Hashable {
        case home, projects, pawn, account
    }
}

private struct PawnProjectHubView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var isCreatingProject = false

    var body: some View {
        ShengbianBackground {
            Group {
                if appStore.projects.isEmpty {
                    ContentUnavailableView {
                        Label("先选择 PAWN 的工作上下文", systemImage: "sparkles")
                    } description: {
                        Text("创建项目后，PAWN 才能把对话、灵感和创作成果连接在一起。")
                    } actions: {
                        ShengbianPrimaryButton(title: "创建项目", symbol: "plus") {
                            isCreatingProject = true
                        }
                        .padding(.horizontal, ShengbianMetrics.pageMargin)
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            Text("选择一个项目，让 PAWN 读取对应上下文并执行应用内操作。")
                                .font(ShengbianTypography.subheadline)
                                .foregroundStyle(ShengbianColors.secondaryText)
                                .padding(.bottom, 4)

                            ForEach(appStore.projects) { project in
                                NavigationLink {
                                    ProjectPawnWorkspaceView(projectID: project.id)
                                } label: {
                                    ShengbianGlassCard {
                                        HStack(spacing: 14) {
                                            Image(systemName: project.kind == .commercial ? "briefcase.fill" : "sparkles")
                                                .font(.headline)
                                                .frame(width: 42, height: 42)
                                                .background(ShengbianColors.glassTintStrong, in: RoundedRectangle(cornerRadius: 8))

                                            VStack(alignment: .leading, spacing: 5) {
                                                Text(project.name)
                                                    .font(ShengbianTypography.bodyEmphasized)
                                                Text(appStore.conversation(for: project.id)?.messages.last?.text ?? project.initialIdea)
                                                    .font(ShengbianTypography.caption)
                                                    .foregroundStyle(ShengbianColors.secondaryText)
                                                    .lineLimit(2)
                                            }

                                            Spacer(minLength: 8)
                                            Image(systemName: "chevron.right")
                                                .font(.caption.bold())
                                                .foregroundStyle(ShengbianColors.tertiaryText)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, ShengbianMetrics.pageMargin)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationTitle("PAWN")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isCreatingProject = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("创建项目")
            }
        }
        .navigationDestination(isPresented: $isCreatingProject) {
            NewProjectView()
        }
    }
}