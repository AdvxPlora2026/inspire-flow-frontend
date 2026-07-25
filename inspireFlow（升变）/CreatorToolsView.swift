import SwiftUI

struct TeleprompterView: View {
    @EnvironmentObject private var appStore: AppStore
    @Environment(\.dismiss) private var dismiss
    var projectID: UUID? = nil
    @State private var selectedCaptureID: UUID?
    @State private var fontSize = 34.0
    @State private var isPlaying = false
    @State private var activeSection = 0

    private var packs: [InspirationCapture] {
        appStore.inspirations.filter {
            $0.bilibiliPack != nil && (projectID == nil || $0.projectID == projectID)
        }
    }

    private var selected: InspirationCapture? {
        let id = selectedCaptureID ?? packs.first?.id
        return packs.first { $0.id == id }
    }

    private var selectedSections: [String] {
        guard let pack = selected?.bilibiliPack else { return [] }
        return scriptSections(for: pack)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let selected, let pack = selected.bilibiliPack {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 36) {
                                ForEach(Array(scriptSections(for: pack).enumerated()), id: \.offset) { index, section in
                                    Text(section)
                                        .font(.system(size: fontSize, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .lineSpacing(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id(index)
                                }
                            }
                            .padding(28)
                        }
                        .task(id: isPlaying) {
                            guard isPlaying else { return }
                            while !Task.isCancelled {
                                try? await Task.sleep(for: .seconds(4))
                                guard !Task.isCancelled, isPlaying else { return }
                                guard !selectedSections.isEmpty else { return }
                                activeSection = (activeSection + 1) % selectedSections.count
                                withAnimation(.easeInOut(duration: 0.8)) {
                                    proxy.scrollTo(activeSection, anchor: .top)
                                }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "还没有提词稿",
                        systemImage: "text.viewfinder",
                        description: Text("先在灵感捕捉或 PAWN 中生成一份创作方案。")
                    )
                }
            }
            .navigationTitle("提词拍摄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button { fontSize = max(22, fontSize - 2) } label: { Image(systemName: "textformat.size.smaller") }
                    Spacer()
                    Button { isPlaying.toggle() } label: { Image(systemName: isPlaying ? "pause.fill" : "play.fill") }
                        .disabled(selected == nil)
                    Spacer()
                    Button { fontSize = min(64, fontSize + 2) } label: { Image(systemName: "textformat.size.larger") }
                }
                if packs.count > 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            ForEach(packs) { capture in
                                Button {
                                    selectedCaptureID = capture.id
                                    activeSection = 0
                                } label: {
                                    Text(capture.bilibiliPack?.title ?? "未命名方案")
                                }
                            }
                        } label: {
                            Image(systemName: "list.bullet")
                        }
                        .accessibilityLabel("选择提词方案")
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func scriptSections(for pack: BilibiliPack) -> [String] {
        [pack.hook, pack.outline, pack.shotList].filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

struct ExportMaterialsView: View {
    @EnvironmentObject private var appStore: AppStore
    @Environment(\.dismiss) private var dismiss

    private var exportText: String {
        let sections = appStore.inspirations.compactMap { capture -> String? in
            guard let pack = capture.bilibiliPack else { return nil }
            return "【\(pack.title)】\n\(pack.hook)\n\(pack.outline)\n\(pack.shotList)"
        }
        return sections.isEmpty ? "暂无可导出的创作方案" : sections.joined(separator: "\n\n---\n\n")
    }

    var body: some View {
        NavigationStack {
            ShengbianBackground {
                VStack(spacing: 20) {
                    ShengbianGlassCard {
                        Text(exportText)
                            .font(ShengbianTypography.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Spacer()
                    ShareLink(item: exportText) {
                        Label("打开系统分享", systemImage: "square.and.arrow.up")
                            .font(ShengbianTypography.headline)
                            .foregroundStyle(ShengbianColors.inverseText)
                            .frame(maxWidth: .infinity, minHeight: ShengbianMetrics.minimumControlHeight)
                            .background(ShengbianColors.primaryAction, in: RoundedRectangle(cornerRadius: ShengbianMetrics.controlRadius))
                    }
                    .disabled(appStore.inspirations.allSatisfy { $0.bilibiliPack == nil })
                }
                .padding(ShengbianMetrics.pageMargin)
            }
            .navigationTitle("导出材料")
            .toolbar { Button("关闭") { dismiss() } }
        }
    }
}

struct RingDeviceView: View {
    @EnvironmentObject private var ring: RingManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        NavigationStack {
            ShengbianBackground {
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .stroke(ShengbianColors.glassBorder, lineWidth: 2)
                            .frame(width: 150, height: 150)
                            .scaleEffect(pulse ? 1.15 : 0.85)
                            .opacity(pulse ? 0.1 : 0.7)
                        Image(systemName: ring.isConnected ? "checkmark.circle.fill" : "dot.radiowaves.left.and.right")
                            .font(.system(size: 52, weight: .semibold))
                            .symbolEffect(.pulse, isActive: ring.state == .scanning || ring.state == .connecting)
                    }
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true }
                    }

                    VStack(spacing: 8) {
                        Text(ring.state.title).font(ShengbianTypography.title2)
                        Text(ring.deviceName ?? "Zilo 戒指")
                            .foregroundStyle(ShengbianColors.secondaryText)
                        if let battery = ring.batteryPercent { Text("电量 \(battery)%").font(ShengbianTypography.technical) }
                        if case .failed(let message) = ring.state { Text(message).foregroundStyle(.orange) }
                    }

                    ShengbianGlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("双击", systemImage: "hand.tap.fill")
                                .font(ShengbianTypography.bodyEmphasized)
                            Text("从任意创作者界面打开灵感捕捉")
                                .font(ShengbianTypography.caption)
                                .foregroundStyle(ShengbianColors.secondaryText)

                            Label("单击", systemImage: "button.programmable")
                                .font(ShengbianTypography.bodyEmphasized)
                            Text("在捕捉页开始或停止录制")
                                .font(ShengbianTypography.caption)
                                .foregroundStyle(ShengbianColors.secondaryText)

                            if let lastEvent = ring.lastEventDescription {
                                Text("最近事件：\(lastEvent)")
                                    .font(ShengbianTypography.technical)
                                    .foregroundStyle(ShengbianColors.tertiaryText)
                            }
                        }
                    }

                    if ring.isConnected {
                        HStack(spacing: 16) {
                            Button { ring.disconnect() } label: { Label("断开连接", systemImage: "xmark.circle") }
                            Button(role: .destructive) { ring.forgetRing() } label: { Label("忘记设备", systemImage: "trash") }
                        }
                    } else {
                        ShengbianPrimaryButton(
                            title: ring.state == .scanning || ring.state == .connecting ? "正在连接…" : "扫描并连接",
                            symbol: "antenna.radiowaves.left.and.right"
                        ) { ring.scanAndConnect() }
                        .disabled(ring.state == .scanning || ring.state == .connecting)
                    }
                    Spacer()
                }
                .padding(ShengbianMetrics.pageMargin)
            }
            .navigationTitle("设备")
            .toolbar { Button("关闭") { dismiss() } }
        }
        .presentationDetents([.medium, .large])
    }
}
