import Foundation
import Combine

/// Coordinates a single viaim live-recording session.
///
/// On success the final transcript is delivered through `transcriptReady`.
/// If the text stream fails but PCM is available, the saved audio file path
/// is delivered through `pcmFallbackURL` so the caller can fall back to
/// backend STT or Direct Whisper.
@MainActor
final class ViaimCaptureSession: ObservableObject {

    @Published var isActive = false
    @Published var livePartial = ""

    let transcriptReady = PassthroughSubject<String, Never>()
    let pcmFallbackURL = PassthroughSubject<URL, Never>()

    private let headset: ViaimHeadsetManager
    private var transcriptCancellable: AnyCancellable?
    private var partialCancellable: AnyCancellable?
    private var pcmData = Data()
    private var pcmFileURL: URL?

    init(headset: ViaimHeadsetManager) {
        self.headset = headset
    }

    func start() {
        guard headset.isAvailable, !isActive else { return }

        isActive = true
        livePartial = ""
        pcmData = Data()

        transcriptCancellable = headset.transcriptReady
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.finish(transcript: text)
            }

        partialCancellable = headset.partialText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.livePartial = text
            }

        headset.startLiveRecording()
    }

    func stop() {
        headset.stopLiveRecording()
    }

    private func finish(transcript: String) {
        isActive = false
        transcriptCancellable = nil
        partialCancellable = nil

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            transcriptReady.send(trimmed)
        } else if let url = pcmFileURL {
            pcmFallbackURL.send(url)
        }
    }

    func cancel() {
        transcriptCancellable = nil
        partialCancellable = nil
        if isActive { headset.stopLiveRecording() }
        isActive = false
        livePartial = ""
        pcmData = Data()
    }

    // MARK: - PCM fallback

    func appendPCM(_ data: Data) {
        pcmData.append(data)
    }

    func finalizePCMFile() -> URL? {
        guard !pcmData.isEmpty else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("viaim-fallback-\(UUID().uuidString).pcm")
        do {
            try pcmData.write(to: url)
            pcmFileURL = url
            return url
        } catch {
            return nil
        }
    }
}
