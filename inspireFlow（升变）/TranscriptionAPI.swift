import Foundation

// MARK: - DTOs

struct TranscriptionJobPublicDTO: Decodable {
    let id: UUID
    let status: String                                          // queued | running | succeeded | failed
    let language: String
    let useITN: Bool
    let text: String?
    let detectedLanguage: String?
    let emotions: [String]?
    let audioEvents: [String]?
    let durationSeconds: Double?
    let error: TranscriptionFailureDTO?
    let attemptCount: Int
    let startedAt: Date?
    let completedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, status, language
        case useITN = "use_itn"
        case text
        case detectedLanguage = "detected_language"
        case emotions
        case audioEvents = "audio_events"
        case durationSeconds = "duration_seconds"
        case error
        case attemptCount = "attempt_count"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isTerminal: Bool { status == "succeeded" || status == "failed" }
    var isSuccess: Bool { status == "succeeded" }
}

struct TranscriptionFailureDTO: Decodable {
    let code: String
    let message: String
}

// MARK: - Transcription API

enum TranscriptionAPI {
    /// Submit an audio file for async transcription. Returns a `202 Accepted` job.
    static func submit(
        accessToken: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        language: String = "auto",
        useITN: Bool = true
    ) async throws -> TranscriptionJobPublicDTO {
        try await APIClient.shared.upload(
            "transcriptions",
            fieldName: "file",
            fileName: fileName,
            mimeType: mimeType,
            fileData: fileData,
            formFields: [
                "language": language,
                "use_itn": useITN ? "true" : "false"
            ],
            accessToken: accessToken,
            idempotencyKey: UUID().uuidString
        )
    }

    /// Poll for job status. Returns the current job document, which includes
    /// `text`, `emotions`, `audio_events`, and `duration_seconds` when succeeded.
    static func status(jobID: UUID, accessToken: String) async throws -> TranscriptionJobPublicDTO {
        try await APIClient.shared.send("transcriptions/\(jobID.uuidString)", accessToken: accessToken)
    }
}
