import Foundation
import Combine

#if canImport(VisionHeadsetOpenSDK)
import VisionHeadsetOpenSDK
#endif

// MARK: - Connection state

enum ViaimConnectionState: Equatable {
    case unconfigured
    case initializing
    case unauthorized(String)
    case bluetoothOff
    case classicBluetoothDisconnected
    case connecting
    case connected
    case recording
    case failed(String)

    var title: String {
        switch self {
        case .unconfigured: "未配置"
        case .initializing: "初始化中"
        case .unauthorized: "授权失败"
        case .bluetoothOff: "蓝牙已关闭"
        case .classicBluetoothDisconnected: "未连接经典蓝牙"
        case .connecting: "连接中"
        case .connected: "已连接"
        case .recording: "录音中"
        case .failed: "连接失败"
        }
    }
}

// MARK: - Audio route

enum ViaimAudioRoute {
    case viaimHeadset
    case phoneMicrophone
    case unavailable
}

// MARK: - Manager

#if canImport(VisionHeadsetOpenSDK)

@MainActor
final class ViaimHeadsetManager: NSObject, ObservableObject {

    // MARK: Published state

    @Published private(set) var connectionState: ViaimConnectionState = .unconfigured
    @Published private(set) var audioRoute: ViaimAudioRoute = .unavailable
    @Published private(set) var deviceName: String?
    @Published private(set) var leftBattery: Int?
    @Published private(set) var rightBattery: Int?
    @Published private(set) var textStreamRunning = false

    /// Aggregates partial results; emits the final transcript when the text stream ends.
    let transcriptReady = PassthroughSubject<String, Never>()

    /// Streams partial text for live display.
    let partialText = PassthroughSubject<String, Never>()

    // MARK: Private

    private var manager: VHOManager { .shared() }
    private var isSDKInitialized = false
    private var pendingPartial = ""
    private var lastFinalText = ""

    private let credentials = ViaimCredentials.load()

    var isAvailable: Bool {
        guard case .connected = connectionState else { return false }
        return true
    }

    var isRecording: Bool {
        connectionState == .recording
    }

    // MARK: - Lifecycle

    func configure() {
        guard !isSDKInitialized else { return }
        guard credentials.isValid else {
            connectionState = .unconfigured
            return
        }

        connectionState = .initializing
        manager.delegate = self
        manager.recordDelegate = self
        manager.openLog(false)

        manager.config.textStream.enabled = true
        manager.config.textStream.enablePartialResult = true

        manager.initialize(
            withAppKey: credentials.appKey,
            appSecret: credentials.appSecret
        ) { [weak self] success, _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if success {
                    self.isSDKInitialized = true
                    self.connectionState = .classicBluetoothDisconnected
                } else {
                    let message = error?.localizedDescription ?? "未知错误"
                    self.connectionState = .unauthorized(message)
                }
            }
        }
    }

    func connect() {
        guard isSDKInitialized else {
            configure()
            return
        }
        connectionState = .connecting
        manager.connectDevice()
    }

    func disconnect() {
        manager.disconnectDevice()
        connectionState = .classicBluetoothDisconnected
        audioRoute = .phoneMicrophone
        deviceName = nil
        leftBattery = nil
        rightBattery = nil
    }

    // MARK: - Recording

    func startLiveRecording() {
        guard manager.connected else { return }
        pendingPartial = ""
        lastFinalText = ""
        manager.start(.live)
    }

    func stopLiveRecording() {
        manager.stop(.live)
    }
}

// MARK: - VisionHeadsetDelegate

extension ViaimHeadsetManager: VisionHeadsetDelegate {

    func visionHeadsetBluetoothStatusDidChanged(_ status: VisionHeadsetBluetoothStatus) {
        switch status {
        case .unknow:
            break
        case .unauthorized:
            connectionState = .unauthorized("蓝牙权限未授权")
        case .powerOff:
            connectionState = .bluetoothOff
        case .powerOn:
            if case .bluetoothOff = connectionState {
                connectionState = .classicBluetoothDisconnected
            }
        @unknown default:
            break
        }
    }

    func visionHeadsetClassicBluetoothConnectStatusDidChanged(_ connected: Bool) {
        if connected, case .classicBluetoothDisconnected = connectionState {
            // Classic Bluetooth is ready; SDK connection can proceed.
        }
    }

    func visionHeadsetConnectionWillStart() {
        connectionState = .connecting
    }

    func visionHeadsetConnectionDidSucceed() {
        connectionState = .connected
        audioRoute = .viaimHeadset
        refreshDeviceInfo()
    }

    func visionHeadsetConnectionDidFailWithError(_ error: Error) {
        let nsError = error as NSError
        let message = (nsError.userInfo["msg"] as? String) ?? error.localizedDescription
        connectionState = .failed(message)
        audioRoute = .phoneMicrophone
    }

    func visionHeadsetConnectionDidDisconnect() {
        if case .recording = connectionState {
            // Recording was in progress; keep the partial text.
        }
        connectionState = .classicBluetoothDisconnected
        audioRoute = .phoneMicrophone
        deviceName = nil
        leftBattery = nil
        rightBattery = nil
        textStreamRunning = false
    }

    func visionHeadsetCallStatusDidChanged() {
        // Not used for inspiration capture; reserved for future call-aware behavior.
    }

    func visionHeadsetDeviceInformationDidChanged() {
        refreshDeviceInfo()
    }

    private func refreshDeviceInfo() {
        let device = manager.device
        deviceName = "viaim \(device.typeNumber)"
        leftBattery = Int(device.leftBatteryLevel)
        rightBattery = Int(device.rightBatteryLevel)
    }
}

// MARK: - VHORecordDelegate

extension ViaimHeadsetManager: VHORecordDelegate {

    func visionHeadsetStartRecordStatus(_ success: Bool, type: VisionHeadsetRecordType, error: Error?) {
        guard type == .live else { return }
        if success {
            connectionState = .recording
        }
    }

    func visionHeadsetStopRecordStatus(_ success: Bool, type: VisionHeadsetRecordType, error: Error?) {
        guard type == .live else { return }
        connectionState = .connected
        textStreamRunning = false

        // Emit the final text if we have one.
        let final = lastFinalText.isEmpty ? pendingPartial.trimmingCharacters(in: .whitespacesAndNewlines) : lastFinalText
        if !final.isEmpty {
            transcriptReady.send(final)
        }
        pendingPartial = ""
        lastFinalText = ""
    }

    func visionHeadsetDidReceivedAudioData(_ data: VisionHeadsetAudioData) {
        // PCM is saved by ViaimCaptureSession; not processed here.
    }

    func visionHeadsetRecordBeInterrupted(_ type: VisionHeadsetRecordType) {
        guard type == .live else { return }
        connectionState = .connected
        textStreamRunning = false

        let saved = lastFinalText.isEmpty ? pendingPartial.trimmingCharacters(in: .whitespacesAndNewlines) : lastFinalText
        if !saved.isEmpty {
            transcriptReady.send(saved)
        }
        pendingPartial = ""
        lastFinalText = ""
    }

    // MARK: Text stream

    func vhoTextStreamDidStart(_ type: VisionHeadsetRecordType) {
        guard type == .live else { return }
        textStreamRunning = true
    }

    func vhoDidReceiveTextStreamResult(_ result: VHOTextStreamResult) {
        guard result.channel == .microphone else { return }
        let text = result.text ?? ""

        if result.type == .final {
            lastFinalText = text
        } else {
            pendingPartial = text
            partialText.send(text)
        }
    }

    func vhoTextStreamDidEnd(_ type: VisionHeadsetRecordType, error: Error?) {
        guard type == .live else { return }
        textStreamRunning = false
    }

    func vhoTextStreamDidFail(toStart type: VisionHeadsetRecordType, error: Error) {
        guard type == .live else { return }
        textStreamRunning = false
    }
}

#else

/// Stub manager when VisionHeadsetOpenSDK is unavailable (simulator / package not yet added).
@MainActor
final class ViaimHeadsetManager: ObservableObject {
    @Published private(set) var connectionState: ViaimConnectionState = .unconfigured
    @Published private(set) var audioRoute: ViaimAudioRoute = .unavailable
    @Published private(set) var deviceName: String? = nil
    @Published private(set) var leftBattery: Int? = nil
    @Published private(set) var rightBattery: Int? = nil
    @Published private(set) var textStreamRunning = false

    let transcriptReady = PassthroughSubject<String, Never>()
    let partialText = PassthroughSubject<String, Never>()

    var isAvailable: Bool { false }
    var isRecording: Bool { false }

    func configure() {}
    func connect() {}
    func disconnect() {}
    func startLiveRecording() {}
    func stopLiveRecording() {}
}

#endif
