import Foundation
import Combine

@MainActor
final class RingManager: ObservableObject {
    enum ConnectionState: Equatable {
        case disconnected
        case scanning
        case connecting
        case connected
        case failed(String)

        var title: String {
            switch self {
            case .disconnected: "未连接"
            case .scanning: "扫描中"
            case .connecting: "连接中"
            case .connected: "已连接"
            case .failed: "连接失败"
            }
        }
    }

    @Published private(set) var state: ConnectionState = .disconnected
    @Published private(set) var deviceName: String?
    @Published private(set) var batteryPercent: Int?
    @Published private(set) var lastEventDescription: String?

    /// Whether an `InspirationRecordView` capture sheet is currently on screen,
    /// regardless of which screen presented it. Shared so a ring gesture never
    /// tries to present a second sheet on top of an already-open one.
    @Published var isCapturePresented = false
    @Published private(set) var captureProjectID: UUID?

    /// Prevents a ring gesture from competing with the device-management sheet.
    @Published var isDeviceManagementPresented = false

    /// Double-click opens capture from anywhere in the creator workspace.
    let captureSignal = PassthroughSubject<Void, Never>()

    /// Single-click controls the active capture session without opening UI by itself.
    let primaryActionSignal = PassthroughSubject<Void, Never>()

    private let savedIdentifierKey = "ring.peripheralIdentifier"
    private var client: RingSoundClient?
    private var eventTask: Task<Void, Never>?
    private var lastCaptureEventAt: Date?

    var isConnected: Bool { state == .connected }

    var hasSavedRing: Bool { savedIdentifier != nil }

    func presentCapture(projectID: UUID? = nil) {
        guard !isCapturePresented, !isDeviceManagementPresented else { return }
        captureProjectID = projectID
        isCapturePresented = true
    }

    func clearCaptureContext() {
        captureProjectID = nil
    }

    private var savedIdentifier: UUID? {
        get { UserDefaults.standard.string(forKey: savedIdentifierKey).flatMap(UUID.init(uuidString:)) }
        set {
            if let value = newValue {
                UserDefaults.standard.set(value.uuidString, forKey: savedIdentifierKey)
            } else {
                UserDefaults.standard.removeObject(forKey: savedIdentifierKey)
            }
        }
    }

    // MARK: - Connection

    /// Scans for a nearby ring (or reuses a saved one) and connects to the first match.
    func scanAndConnect() {
        guard state != .scanning, state != .connecting else { return }
        state = .scanning
        Task {
            do {
                let saved = savedIdentifier
                let devices = try await scanRings(identifier: saved, timeout: 20)
                let match: BLEDeviceInfo?
                if saved != nil {
                    match = devices.first
                } else {
                    match = devices
                        .filter { ($0.name ?? "").localizedCaseInsensitiveContains("ring") }
                        .max { ($0.rssi ?? Int.min) < ($1.rssi ?? Int.min) }
                }
                guard let device = match,
                      let identifier = UUID(uuidString: device.address) else {
                    state = .failed("未发现戒指")
                    return
                }
                await connect(identifier: identifier, name: device.name)
            } catch {
                state = .failed(Self.message(for: error))
            }
        }
    }

    /// Reconnects to the previously saved ring, if any.
    func reconnectSaved() {
        guard let identifier = savedIdentifier else { return }
        state = .connecting
        Task { await connect(identifier: identifier, name: nil) }
    }

    func disconnect() {
        eventTask?.cancel()
        eventTask = nil
        let current = client
        client = nil
        state = .disconnected
        deviceName = nil
        batteryPercent = nil
        Task { await current?.disconnect() }
    }

    func forgetRing() {
        savedIdentifier = nil
        disconnect()
    }

    private func connect(identifier: UUID, name: String?) async {
        state = .connecting
        do {
            let ring = RingSoundClient(identifier: identifier)
            try await ring.connect()
            client = ring
            savedIdentifier = identifier
            deviceName = name ?? deviceName
            state = .connected
            await refreshInfo()
            startEventLoop()
        } catch {
            client = nil
            state = .failed(Self.message(for: error))
        }
    }

    private func refreshInfo() async {
        guard let client else { return }
        if let info = try? await client.getSystemInfo(timeout: 5) {
            batteryPercent = Int(info.batteryPercent)
            if deviceName == nil { deviceName = info.model }
        }
    }

    // MARK: - Event loop

    private func startEventLoop() {
        guard let client else { return }
        eventTask?.cancel()
        eventTask = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await self?.captureLoop(
                        client,
                        awaiting: { _ = try await $0.waitForKeyDoublePressEvent(timeout: 30) },
                        label: "戒指按键双击"
                    )
                }
                group.addTask {
                    await self?.captureLoop(
                        client,
                        awaiting: { _ = try await $0.waitForDoubleTapEvent(timeout: 30) },
                        label: "戒指双击"
                    )
                }
                group.addTask {
                    await self?.primaryActionLoop(
                        client,
                        awaiting: { _ = try await $0.waitForKeySinglePressEvent(timeout: 30) },
                        label: "戒指单击"
                    )
                }
            }
        }
    }

    private func captureLoop(
        _ client: RingSoundClient,
        awaiting event: @escaping (RingSoundClient) async throws -> Void,
        label: String
    ) async {
        while !Task.isCancelled {
            do {
                try await event(client)
                guard !Task.isCancelled else { return }
                fireCapture(label)
            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled { return }
                // Timeouts are expected; back off briefly on any other transient error.
                try? await Task.sleep(for: .milliseconds(300))
            }
        }
    }

    private func primaryActionLoop(
        _ client: RingSoundClient,
        awaiting event: @escaping (RingSoundClient) async throws -> Void,
        label: String
    ) async {
        while !Task.isCancelled {
            do {
                try await event(client)
                guard !Task.isCancelled else { return }
                lastEventDescription = label
                primaryActionSignal.send()
            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled { return }
                try? await Task.sleep(for: .milliseconds(300))
            }
        }
    }

    private func fireCapture(_ label: String) {
        let now = Date()
        if let lastCaptureEventAt,
           now.timeIntervalSince(lastCaptureEventAt) < 0.75 {
            return
        }
        lastCaptureEventAt = now
        lastEventDescription = label
        captureSignal.send()
    }

    // MARK: - Helpers

    private static func message(for error: Error) -> String {
        guard let ringError = error as? RingSoundError else {
            return error.localizedDescription
        }
        switch ringError {
        case .transport(let message): return "蓝牙错误：\(message)"
        case .timeout: return "连接超时"
        case .device(_, let message): return "设备错误：\(message)"
        case .protocolError(let message): return "协议错误：\(message)"
        default: return error.localizedDescription
        }
    }
}
