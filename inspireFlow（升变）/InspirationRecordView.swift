import SwiftUI

struct InspirationRecordView: View {
    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var ring: RingManager
    @EnvironmentObject private var headset: ViaimHeadsetManager
    @EnvironmentObject private var speechOutput: SpeechOutputService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var audioRecorder = AudioRecorder()

    var projectID: UUID?

    @State private var phase: RecordPhase = .ready
    @State private var elapsed: TimeInterval = 0
    @State private var transcription = ""
    @State private var questions = [
        "这条视频最想讲给谁看？",
        "你希望它是什么形式？",
        "最重要的开场画面是什么？"
    ]
    @State private var questionIndex = 0
    @State private var answers: [String] = []
    @State private var answerDraft = ""
    @State private var pawnConversationID: UUID?
    @State private var isPawnWorking = false
    @State private var privacy: InspirationPrivacy = .privateOnly
    @State private var timer: Timer?
    @State private var savedCapture: InspirationCapture?
    @State private var pulse = false
    @State private var recordedAudioURL: URL?
    @State private var processingError: String?
    @State private var isSTTUnavailable = false
    @State private var viaimSession: ViaimCaptureSession?
    @State private var viaimPartial = ""

    private let demoAnswers = [
        "第一次尝试无屏创作的 B 站创作者",
        "60 秒现场竖屏短视频",
        "创作者正在拍摄，却突然冒出一个灵感"
    ]

    var body: some View {
        ShengbianBackground {
            VStack(spacing: 0) {
                toolbar
                    .padding(.horizontal, ShengbianMetrics.pageMargin)
                    .padding(.top, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch phase {
                        case .ready:
                            readySection
                                .transition(sectionTransition)
                        case .recording:
                            recordingSection
                                .transition(sectionTransition)
                        case .transcribing:
                            transcribingSection
                                .transition(sectionTransition)
                        case .questioning:
                            questioningSection
                                .transition(sectionTransition)
                        case .generating:
                            generatingSection
                                .transition(sectionTransition)
                        case .done:
                            if let capture = savedCapture {
                                doneSection(capture)
                                    .transition(sectionTransition)
                            }
                        }
                    }
                    .padding(.horizontal, ShengbianMetrics.pageMargin)
                    .padding(.vertical, 24)
                }

                if phase == .ready {
                    bottomBar
                }
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear {
            stopTimer()
            audioRecorder.discard()
            viaimSession?.cancel()
            viaimSession = nil
        }
        .onReceive(ring.primaryActionSignal) { handleCaptureToggle() }
        .onReceive(headset.transcriptReady) { text in
            guard viaimSession != nil, !text.isEmpty else { return }
            handleViaimTranscript(text)
        }
    }

    private var sectionTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .opacity.combined(with: .move(edge: .bottom))
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(ShengbianColors.glassTint, in: Circle())
            }
            .accessibilityLabel("关闭")

            Spacer()

            AppBrandMark(compact: true)

            Spacer()

            privacyMenu
        }
    }

    private var privacyMenu: some View {
        Menu {
            ForEach(InspirationPrivacy.allCases) { level in
                Button {
                    privacy = level
                } label: {
                    Label(level.title, systemImage: level.symbol)
                }
            }
        } label: {
            Label(privacy.title, systemImage: privacy.symbol)
                .font(ShengbianTypography.caption)
                .foregroundStyle(ShengbianColors.secondaryText)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(ShengbianColors.glassTint, in: Capsule())
                .overlay { Capsule().strokeBorder(ShengbianColors.glassBorder) }
        }
        .accessibilityLabel("隐私设置，当前：\(privacy.title)")
    }

    // MARK: - Ready

    private var readySection: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 8) {
                Text("捕捉灵感")
                    .font(ShengbianTypography.display)
                Text("说出刚刚想到的，PAWN 会帮你记下来，然后问三个问题。")
                    .shengbianBodyText(secondary: true)
            }

            captureButton(isListening: false)

            demoFallbackNote
        }
    }

    // MARK: - Recording

    private var recordingSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                ShengbianStatusLabel(title: "正在录制", symbol: "waveform", state: .listening)
                Spacer()
                Text(formattedElapsed)
                    .font(ShengbianTypography.metric)
                    .foregroundStyle(ShengbianColors.secondaryText)
                    .contentTransition(.numericText())
                    .accessibilityLabel("录制时长 \(formattedElapsed)")
            }

            captureButton(isListening: true)

            ShengbianGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label(session.isDemoMode ? "实时转录（演示模式）" : "录音将在停止后安全转录", systemImage: "text.bubble")
                        .font(ShengbianTypography.caption)
                        .foregroundStyle(ShengbianColors.tertiaryText)

                    Text(transcription.isEmpty ? "正在聆听…" : transcription)
                        .font(ShengbianTypography.body)
                        .foregroundStyle(transcription.isEmpty ? ShengbianColors.tertiaryText : ShengbianColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: transcription)
                }
            }
        }
    }

    private var transcribingSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let processingError {
                ShengbianStatusLabel(title: "转录失败", symbol: "exclamationmark.triangle.fill", state: .warning)
                ShengbianGlassCard {
                    Text(processingError)
                        .font(ShengbianTypography.body)
                        .foregroundStyle(ShengbianColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 12) {
                    Button("重试转录") {
                        Task { await transcribeRecording() }
                    }
                    .buttonStyle(.borderedProminent)

                    if isSTTUnavailable {
                        Button("改用模拟转写继续") {
                            Task { await useSimulatedTranscription() }
                        }
                        .buttonStyle(.bordered)
                        .tint(ShengbianColors.listening)
                    }

                    Button("重新录制") {
                        audioRecorder.discard()
                        recordedAudioURL = nil
                        self.processingError = nil
                        isSTTUnavailable = false
                        viaimSession?.cancel()
                        viaimSession = nil
                        viaimPartial = ""
                        phase = .ready
                    }
                    .buttonStyle(.bordered)
                }
            } else if viaimSession != nil || (viaimPartial.isEmpty && transcription.isEmpty && headset.textStreamRunning) {
                // Waiting for viaim final text.
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                    Text("正在等待 viaim 最终文本…")
                        .font(ShengbianTypography.headline)
                    Text(viaimPartial.isEmpty ? "耳机文本流处理中。" : "已收到部分文本，等待确认。")
                        .shengbianBodyText(secondary: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("正在上传并转录录音…")
                    .font(ShengbianTypography.headline)
                Text("请保持网络连接。完成后灵感会保存到你的账户。")
                    .shengbianBodyText(secondary: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - PAWN Questioning

    private var questioningSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                ShengbianStatusLabel(title: "PAWN 追问", symbol: "sparkles", state: .neutral)
                Spacer()
                Text("\(questionIndex + 1) / \(questions.count)")
                    .font(ShengbianTypography.technical)
                    .foregroundStyle(ShengbianColors.secondaryText)
                    .contentTransition(.numericText())
            }

            ShengbianGlassCard(emphasis: .prominent) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(questions[questionIndex])
                        .font(ShengbianTypography.title3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(session.isDemoMode ? "使用演示答案继续：" : "输入回答，PAWN 会继续追问：")
                        .font(ShengbianTypography.caption)
                        .foregroundStyle(ShengbianColors.tertiaryText)
                }
            }
            .onAppear {
                guard !session.isDemoMode, headset.isAvailable else { return }
                speechOutput.speak(questions[questionIndex])
            }
            .onDisappear {
                speechOutput.stop()
            }

            if session.isDemoMode {
                Button {
                    submitAnswer(demoAnswers[questionIndex])
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform")
                        Text(demoAnswers[questionIndex])
                            .font(ShengbianTypography.bodyEmphasized)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .foregroundStyle(ShengbianColors.inverseText)
                    .padding(14)
                    .background(
                        ShengbianColors.primaryAction,
                        in: RoundedRectangle(cornerRadius: ShengbianMetrics.controlRadius, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            } else {
                TextField("输入你的回答", text: $answerDraft, axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(
                        ShengbianColors.glassTintStrong,
                        in: RoundedRectangle(cornerRadius: ShengbianMetrics.controlRadius)
                    )

                Button {
                    submitAnswer(answerDraft)
                } label: {
                    HStack {
                        if isPawnWorking { ProgressView().tint(.black) }
                        Text(questionIndex == 2 ? "生成方案" : "提交回答")
                        Spacer()
                        Image(systemName: "arrow.up")
                    }
                    .font(ShengbianTypography.headline)
                    .foregroundStyle(ShengbianColors.inverseText)
                    .padding(.horizontal, 16)
                    .frame(minHeight: ShengbianMetrics.minimumControlHeight)
                    .background(
                        ShengbianColors.primaryAction,
                        in: RoundedRectangle(cornerRadius: ShengbianMetrics.controlRadius)
                    )
                }
                .buttonStyle(.plain)
                .disabled(answerDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPawnWorking)
            }

            if !answers.isEmpty {
                previousAnswers
            }
        }
    }

    private var previousAnswers: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("已回答")
                .font(ShengbianTypography.caption)
                .foregroundStyle(ShengbianColors.tertiaryText)

            ForEach(Array(answers.enumerated()), id: \.offset) { index, answer in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(ShengbianColors.success)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(questions[index])
                            .font(ShengbianTypography.caption)
                            .foregroundStyle(ShengbianColors.tertiaryText)
                        Text(answer)
                            .font(ShengbianTypography.subheadline)
                    }
                }
            }
        }
    }

    // MARK: - Generating

    private var generatingSection: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 40)

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)

                Text("PAWN 正在生成 Bilibili 创作方案…")
                    .font(ShengbianTypography.subheadline)
                    .foregroundStyle(ShengbianColors.secondaryText)
                    .multilineTextAlignment(.center)
            }

            demoFallbackNote

            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
        .task { await generatePlan() }
    }

    // MARK: - Done

    private func doneSection(_ capture: InspirationCapture) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                ShengbianStatusLabel(
                    title: capture.bilibiliPack == nil ? "灵感已保存" : "创作方案已生成",
                    symbol: "checkmark.circle.fill",
                    state: .success
                )
                if capture.isDemoFallback {
                    ShengbianStatusLabel(title: "演示数据", symbol: "info.circle", state: .warning)
                }
            }

            if let pid = capture.projectID,
               let project = appStore.projects.first(where: { $0.id == pid }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.caption)
                        .foregroundStyle(ShengbianColors.secondaryText)
                    Text("已保存到《\(project.name)》")
                        .font(ShengbianTypography.caption)
                        .foregroundStyle(ShengbianColors.secondaryText)
                    Spacer()
                }
                .padding(.horizontal, 2)
            }

            if let pack = capture.bilibiliPack {
                bilibiliPackCard(pack)
            }

            pawnQACard(capture.pawnQAs)

            shareAndSaveButtons(capture)
        }
    }

    private func bilibiliPackCard(_ pack: BilibiliPack) -> some View {
        ShengbianGlassCard(emphasis: .prominent) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Bilibili 创作方案")
                    .font(ShengbianTypography.headline)

                packRow(label: "标题", value: pack.title)
                packRow(label: "3 秒钩子", value: pack.hook)
                packRow(label: "结构大纲", value: pack.outline)
                packRow(label: "拍摄清单", value: pack.shotList)
            }
        }
    }

    private func packRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(ShengbianTypography.label)
                .foregroundStyle(ShengbianColors.secondaryText)
            Text(value)
                .font(ShengbianTypography.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func pawnQACard(_ qas: [PawnQA]) -> some View {
        ShengbianGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("PAWN 三问记录")
                    .font(ShengbianTypography.headline)

                ForEach(qas) { qa in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(qa.question)
                            .font(ShengbianTypography.caption)
                            .foregroundStyle(ShengbianColors.secondaryText)
                        Text(qa.answer)
                            .font(ShengbianTypography.subheadline)
                    }
                }
            }
        }
    }

    private func shareAndSaveButtons(_ capture: InspirationCapture) -> some View {
        VStack(spacing: 10) {
            if let pack = capture.bilibiliPack {
                let shareText = buildShareText(pack: pack, qas: capture.pawnQAs)
                ShareLink(item: shareText) {
                    HStack(spacing: 10) {
                        Text("导出 Bilibili 方案")
                            .font(ShengbianTypography.headline)
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
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
                .buttonStyle(.plain)
            }

            Button {
                dismiss()
            } label: {
                Text("完成")
                    .font(ShengbianTypography.headline)
                    .foregroundStyle(ShengbianColors.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: ShengbianMetrics.minimumControlHeight)
                    .background(
                        ShengbianColors.glassTintStrong,
                        in: RoundedRectangle(cornerRadius: ShengbianMetrics.controlRadius, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: ShengbianMetrics.controlRadius, style: .continuous)
                            .strokeBorder(ShengbianColors.glassBorder)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Capture Button

    private func captureButton(isListening: Bool) -> some View {
        Button {
            handleCaptureToggle()
        } label: {
            VStack(spacing: 20) {
                ZStack {
                    ForEach(isListening ? [1.0, 0.72] : [1.0], id: \.self) { scale in
                        Circle()
                            .strokeBorder(
                                isListening
                                    ? ShengbianColors.listening.opacity(0.18 + (1 - scale) * 0.2)
                                    : ShengbianColors.primaryText.opacity(0.08),
                                lineWidth: 1
                            )
                            .frame(width: 140 * scale, height: 140 * scale)
                            .scaleEffect(isListening && pulse && !reduceMotion ? 1.08 : 1)
                            .opacity(isListening && pulse && !reduceMotion ? 0.55 : 1)
                    }

                    Image(systemName: isListening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isListening ? ShengbianColors.listening : ShengbianColors.inverseText)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 64, height: 64)
                        .background(
                            isListening ? ShengbianColors.listening.opacity(0.18) : ShengbianColors.primaryAction,
                            in: Circle()
                        )
                }
                .frame(height: 140)
                .animation(
                    reduceMotion ? nil : ShengbianMotion.pulse.repeatForever(autoreverses: true),
                    value: pulse
                )
                .accessibilityHidden(true)

                Text(isListening ? "轻点停止录制" : "轻点开始说话")
                    .font(ShengbianTypography.headline)
                Text(isListening ? "停止后进入 PAWN 追问" : "也可以双击 Zilo 戒指唤醒")
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.secondaryText)
            }
            .foregroundStyle(ShengbianColors.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: ShengbianMetrics.cardRadius, style: .continuous))
            .background(ShengbianColors.glassTintStrong, in: RoundedRectangle(cornerRadius: ShengbianMetrics.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: ShengbianMetrics.cardRadius, style: .continuous)
                    .strokeBorder(
                        isListening ? ShengbianColors.listening.opacity(0.5) : ShengbianColors.glassHighlight,
                        lineWidth: isListening ? 1.25 : 0.8
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isListening ? "停止录制" : "开始录制")
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider().background(ShengbianColors.glassBorder)

            HStack {
                Text(session.isDemoMode ? "当前使用演示转录，不会请求麦克风权限" : "录音会上传到你的账户并由后端转录")
                    .font(ShengbianTypography.caption)
                    .foregroundStyle(ShengbianColors.tertiaryText)
                Spacer()
                Image(systemName: session.isDemoMode ? "waveform.badge.exclamationmark" : "lock.shield.fill")
                    .foregroundStyle(session.isDemoMode ? ShengbianColors.warning : ShengbianColors.success)
                    .font(.caption)
            }
            .padding(.horizontal, ShengbianMetrics.pageMargin)
            .padding(.vertical, 10)
        }
    }

    private var demoFallbackNote: some View {
        Label(
            session.isDemoMode ? "123 演示账户使用固定数据" : "真实账户使用麦克风和后端语音识别",
            systemImage: session.isDemoMode ? "info.circle" : "checkmark.shield"
        )
            .font(ShengbianTypography.technical)
            .foregroundStyle(ShengbianColors.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Logic

    private var formattedElapsed: String {
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func handleCaptureToggle() {
        switch phase {
        case .ready:
            Task { await startRecording() }
        case .recording:
            stopRecording()
        default:
            break
        }
    }

    private func startRecording() async {
        processingError = nil
        transcription = ""
        viaimPartial = ""

        // Prefer viaim headset when connected.
        if headset.isAvailable, !session.isDemoMode {
            let session = ViaimCaptureSession(headset: headset)
            viaimSession = session
            session.start()
            Haptics.impact(.medium)
            withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.84)) {
                phase = .recording
            }
            pulse = true
            elapsed = 0
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                Task { @MainActor in
                    elapsed += 1
                    // Mirror viaim partial text into the display.
                    if let s = self.viaimSession {
                        self.viaimPartial = s.livePartial
                    }
                }
            }
            return
        }

        if !session.isDemoMode {
            guard session.accessToken != nil else {
                processingError = "登录状态不可用，请退出后重新登录。"
                phase = .transcribing
                return
            }
            do {
                try await audioRecorder.start()
            } catch {
                processingError = error.localizedDescription
                phase = .transcribing
                return
            }
        }
        Haptics.impact(.medium)
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.84)) {
            phase = .recording
        }
        pulse = true
        elapsed = 0
        if session.isDemoMode {
            simulateTranscription()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                elapsed += 1
            }
        }
    }

    private func stopRecording() {
        stopTimer()
        pulse = false
        Haptics.impact(.rigid)

        if let session = viaimSession {
            session.stop()
            // Final text will arrive via headset.transcriptReady → handleViaimTranscript.
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                phase = .transcribing
            }
            return
        }

        viaimSession = nil
        if session.isDemoMode {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                phase = .questioning
                questionIndex = 0
                answers = []
            }
        } else {
            recordedAudioURL = audioRecorder.stop()
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                phase = .transcribing
            }
            Task { await transcribeRecording() }
        }
    }

    /// Called when the viaim text stream delivers a final transcript.
    private func handleViaimTranscript(_ text: String) {
        transcription = text
        viaimSession?.cancel()
        viaimSession = nil
        viaimPartial = ""

        guard !text.isEmpty else {
            processingError = "viaim 未返回有效文本，请重试。"
            return
        }

        if let accessToken = session.accessToken {
            Task {
                do {
                    try await beginPawnFlow(transcription: text, accessToken: accessToken)
                } catch {
                    processingError = error.localizedDescription
                    Haptics.error()
                }
            }
        } else {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                phase = .questioning
                questionIndex = 0
                answers = []
            }
        }
    }

    private func transcribeRecording() async {
        guard let recordedAudioURL else {
            processingError = "没有找到录音文件，请重新录制。"
            return
        }

        processingError = nil
        isSTTUnavailable = false
        do {
            let audioData = try Data(contentsOf: recordedAudioURL)

            // 直连 Replicate Whisper，不依赖后端 STT
            let text = try await DirectWhisperClient.shared.transcribe(
                audioData: audioData,
                mimeType: "audio/mp4"
            )
            transcription = text
            audioRecorder.discard()
            self.recordedAudioURL = nil

            if let accessToken = session.accessToken {
                try await beginPawnFlow(transcription: text, accessToken: accessToken)
            } else {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    phase = .questioning
                    questionIndex = 0
                    answers = []
                }
            }
        } catch {
            processingError = "转写失败：\(error.localizedDescription)\n请重试，或使用模拟转写继续。"
            isSTTUnavailable = true
            Haptics.error()
        }
    }

    /// Fall back to simulated transcription when STT keeps failing.
    private func useSimulatedTranscription() async {
        processingError = nil
        isSTTUnavailable = false
        transcription = "我想做一期关于随手用语音捕捉灵感、再由 PAWN 完成 B 站创作方案的视频。"
        audioRecorder.discard()
        recordedAudioURL = nil
        if let accessToken = session.accessToken {
            do {
                try await beginPawnFlow(transcription: transcription, accessToken: accessToken)
            } catch {
                processingError = error.localizedDescription
                Haptics.error()
            }
        } else {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                phase = .questioning
                questionIndex = 0
                answers = []
            }
        }
    }

    private func simulateTranscription() {
        let demo = "我想做一期关于随手用语音捕捉灵感、再由 PAWN 完成 B 站创作方案的视频。"
        var index = demo.startIndex

        Task { @MainActor in
            while index < demo.endIndex {
                guard phase == .recording else { return }
                let next = demo.index(after: index)
                transcription += String(demo[index..<next])
                index = next
                try? await Task.sleep(for: .milliseconds(60))
            }
        }
    }

    private func submitAnswer(_ answer: String) {
        let normalizedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedAnswer.isEmpty else { return }
        Haptics.selection()
        answers.append(normalizedAnswer)
        answerDraft = ""
        if session.isDemoMode {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                if questionIndex < questions.count - 1 {
                    questionIndex += 1
                } else {
                    phase = .generating
                }
            }
        } else if questionIndex < 2 {
            Task { await requestNextQuestion(after: normalizedAnswer) }
        } else {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { phase = .generating }
        }
    }

    private func beginPawnFlow(transcription: String, accessToken: String) async throws {
        let title = projectID.flatMap { id in appStore.projects.first(where: { $0.id == id })?.name } ?? "语音灵感"
        let conversation = try await ConversationAPI.create(title: title, accessToken: accessToken)
        pawnConversationID = conversation.id
        if let projectID { appStore.setRemoteConversationID(conversation.id, for: projectID) }
        let turn = try await ConversationAPI.sendMessage(
            conversation.id,
            content: """
            这是一条刚完成转写的创作灵感：\(transcription)
            你是创作搭档 PAWN。请只提出第一个最关键的澄清问题，问题应简短、具体，不要解释。
            """,
            accessToken: accessToken
        )
        questions = [normalizedQuestion(turn.assistantMessage.content)]
        questionIndex = 0
        answers = []
        processingError = nil
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { phase = .questioning }
        Haptics.success()
    }

    private func requestNextQuestion(after answer: String) async {
        guard let accessToken = session.accessToken, let pawnConversationID else { return }
        isPawnWorking = true
        defer { isPawnWorking = false }
        do {
            let nextNumber = questions.count + 1
            let turn = try await ConversationAPI.sendMessage(
                pawnConversationID,
                content: "我的回答：\(answer)\n请只提出第 \(nextNumber) 个关键问题，不要重复之前的问题，不要解释。",
                accessToken: accessToken
            )
            questions.append(normalizedQuestion(turn.assistantMessage.content))
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { questionIndex += 1 }
        } catch {
            processingError = "PAWN 追问失败：\(error.localizedDescription)"
            Haptics.error()
        }
    }

    private func normalizedQuestion(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func generatePlan() async {
        if session.isDemoMode {
            await simulateGeneration()
            return
        }
        guard let accessToken = session.accessToken, let pawnConversationID else {
            processingError = "PAWN 会话不可用，请重新录制。"
            phase = .transcribing
            return
        }
        do {
            let turn = try await ConversationAPI.sendMessage(
                pawnConversationID,
                content: """
                三个问题已经回答完毕。请生成可直接执行的 Bilibili 创作方案，并严格使用以下四行格式：
                标题：...
                3秒钩子：...
                结构大纲：...
                拍摄清单：...
                """,
                accessToken: accessToken
            )
            let response = turn.assistantMessage.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let qas = zip(questions, answers).map { PawnQA(id: UUID(), question: $0.0, answer: $0.1) }
            let capture = try await appStore.addInspiration(
                transcription: transcription,
                pawnQAs: qas,
                bilibiliPack: parsePack(response),
                projectID: projectID,
                privacy: privacy,
                isDemoFallback: false,
                sourceType: .voice,
                accessToken: accessToken
            )
            savedCapture = capture
            phase = .done
            Haptics.success()
        } catch {
            processingError = "PAWN 生成失败：\(error.localizedDescription)"
            phase = .transcribing
            Haptics.error()
        }
    }

    private func parsePack(_ response: String) -> BilibiliPack {
        func value(after labels: [String]) -> String? {
            response.split(whereSeparator: \.isNewline).compactMap { rawLine -> String? in
                let line = String(rawLine).trimmingCharacters(in: .whitespaces)
                guard let label = labels.first(where: { line.hasPrefix($0) }) else { return nil }
                return String(line.dropFirst(label.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }.first
        }
        return BilibiliPack(
            title: value(after: ["标题：", "标题:"]) ?? "从一句灵感开始",
            hook: value(after: ["3秒钩子：", "3 秒钩子：", "3秒钩子:"]) ?? "用最真实的一刻抓住观众。",
            outline: value(after: ["结构大纲：", "结构大纲:"]) ?? response,
            shotList: value(after: ["拍摄清单：", "拍摄清单:"]) ?? "根据结构大纲拆分现场镜头"
        )
    }

    private func simulateGeneration() async {
        try? await Task.sleep(for: .seconds(2))

        let qas = zip(questions, answers.prefix(3)).map { q, a in
            PawnQA(id: UUID(), question: q, answer: a)
        }

        let pack = BilibiliPack(
            title: "我用一句话，接住了差点消失的灵感",
            hook: "最好的创作工具，也许根本没有屏幕。",
            outline: "灵感丢失 → 一句话录下 → PAWN 追问 → 成片",
            shotList: "现场走拍、开口瞬间、追问反馈、方案结果页"
        )

        let finalTranscription = transcription.isEmpty ? "（演示转录）" : transcription
        let capture: InspirationCapture
        do {
            capture = try await appStore.addInspiration(
                transcription: finalTranscription,
                pawnQAs: qas,
                bilibiliPack: pack,
                projectID: projectID,
                privacy: privacy,
                isDemoFallback: true,
                accessToken: session.accessToken
            )
        } catch {
            capture = appStore.addInspiration(
                transcription: finalTranscription,
                pawnQAs: qas,
                bilibiliPack: pack,
                projectID: projectID,
                privacy: privacy,
                isDemoFallback: true
            )
        }

        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            savedCapture = capture
            phase = .done
        }
        Haptics.success()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func buildShareText(pack: BilibiliPack, qas: [PawnQA]) -> String {
        var lines = [
            "【升变 PAWN · Bilibili 创作方案】",
            "",
            "标题：\(pack.title)",
            "3 秒钩子：\(pack.hook)",
            "结构大纲：\(pack.outline)",
            "拍摄清单：\(pack.shotList)",
            "",
            "PAWN 三问："
        ]
        for qa in qas {
            lines.append("Q：\(qa.question)")
            lines.append("A：\(qa.answer)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Phase

private enum RecordPhase {
    case ready
    case recording
    case transcribing
    case questioning
    case generating
    case done
}

private enum TranscriptionFlowError: LocalizedError {
    case timedOut
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .timedOut: "转录等待超时，录音仍保留，可稍后重试。"
        case .failed(let message): message
        }
    }
}

#Preview("InspirationRecordView") {
    InspirationRecordView()
        .environmentObject(AppStore())
        .environmentObject(RingManager())
}
