import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var ring: RingManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var isConfirmingSignOut = false
    @State private var isEditingCreatorProfile = false
    @State private var isShowingWorkshop = false
    @State private var isShowingGuide = false
    @State private var guideCompletion = false
    @State private var isConfirmingReset = false
    @State private var isConfirmingSeed = false

    var body: some View {
        AppBackground {
            List {
                Section {
                    HStack(spacing: 14) {
                        Text(String(session.displayName.prefix(1)).uppercased())
                            .font(.title2.bold())
                            .foregroundStyle(.black)
                            .frame(width: 54, height: 54)
                            .background(Color.white, in: Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.displayName).font(.headline)
                            Text(session.role.title).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 5)
                }

                Section("工作空间") {
                    if session.role == .creator {
                        Button {
                            isEditingCreatorProfile = true
                        } label: {
                            Label("创作者资料与可见性", systemImage: "person.text.rectangle")
                        }

                        Button {
                            isShowingWorkshop = true
                        } label: {
                            Label("创作主页与品牌授权", systemImage: "megaphone.fill")
                        }
                        .disabled(session.isDemoMode)
                    }

                    Button {
                        session.switchRole()
                    } label: {
                        Label(
                            session.role == .creator ? "切换为品牌方视角" : "切换为创作者视角",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                    }

                    Label(
                        session.isDemoMode ? "演示模式 — 数据仅保存在本机" : "在线模式 — 数据已同步到云端",
                        systemImage: session.isDemoMode ? "exclamationmark.shield" : "icloud.fill"
                    )
                    .foregroundStyle(session.isDemoMode ? .orange : ShengbianColors.success)
                }

                Section {
                    HStack {
                        Label(ring.state.title, systemImage: ring.isConnected ? "dot.radiowaves.left.and.right" : "circle.dashed")
                            .foregroundStyle(ring.isConnected ? .green : .secondary)
                        Spacer()
                        if let battery = ring.batteryPercent {
                            Text("\(battery)%").foregroundStyle(.secondary)
                        }
                    }

                    if let name = ring.deviceName {
                        Label(name, systemImage: "circle.circle")
                            .foregroundStyle(.secondary)
                    }

                    if ring.isConnected {
                        Button(role: .destructive) {
                            ring.disconnect()
                        } label: {
                            Label("断开连接", systemImage: "xmark.circle")
                        }
                    } else {
                        Button {
                            ring.scanAndConnect()
                        } label: {
                            Label(ring.state == .scanning ? "扫描中…" : "扫描并连接戒指", systemImage: "antenna.radiowaves.left.and.right")
                        }
                        .disabled(ring.state == .scanning || ring.state == .connecting)
                    }

                    if case .failed(let message) = ring.state {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Zilo 戒指（可选配件）")
                } footer: {
                    Text("戒指用于无屏触发捕捉，不连接也能正常使用全部功能。")
                }

                Section("帮助") {
                    Button {
                        isShowingGuide = true
                    } label: {
                        Label("重新查看产品引导", systemImage: "questionmark.circle")
                    }

                    Button {
                        isConfirmingSeed = true
                    } label: {
                        Label("注入演示数据（多场景展示）", systemImage: "square.and.arrow.down.on.square.fill")
                    }

                    if session.isDemoMode {
                        Button(role: .destructive) {
                            isConfirmingReset = true
                        } label: {
                            Label("重置演示数据", systemImage: "arrow.counterclockwise")
                        }
                    }
                }

                Section {
                    Button(role: .destructive) { isConfirmingSignOut = true } label: {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("我的")
        .confirmationDialog("确定退出登录？", isPresented: $isConfirmingSignOut) {
            Button("退出登录", role: .destructive) { session.signOut() }
        }
        .confirmationDialog("重置演示数据？", isPresented: $isConfirmingReset, titleVisibility: .visible) {
            Button("重置", role: .destructive) { appStore.resetDemoData() }
        } message: {
            Text("将恢复默认的演示灵感和项目，不会退出登录或清除账号信息。")
        }
        .confirmationDialog("注入演示数据？", isPresented: $isConfirmingSeed, titleVisibility: .visible) {
            Button("注入（替换现有数据）", role: .destructive) { appStore.seedRichDemoData() }
        } message: {
            Text("将用 5 个项目、10 条灵感、完整 PAWN 对话和商业链上履约数据替换当前数据。此操作不可撤销，建议先截图当前布局。")
        }
        .sheet(isPresented: $isEditingCreatorProfile) {
            CreatorProfileSetupView(mode: .editing)
        }
        .sheet(isPresented: $isShowingWorkshop) {
            WorkshopView()
        }
        .fullScreenCover(isPresented: $isShowingGuide) {
            StartView(hasCompletedOnboarding: $guideCompletion)
                .overlay(alignment: .topTrailing) {
                    Button {
                        isShowingGuide = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(20)
                    }
                    .accessibilityLabel("关闭引导")
                }
                .onChange(of: guideCompletion) { _, completed in
                    if completed {
                        isShowingGuide = false
                        guideCompletion = false
                    }
                }
        }
    }
}