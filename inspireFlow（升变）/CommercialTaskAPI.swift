import Foundation

// MARK: - Budget

struct BudgetDTO: Codable {
    let amount: String
    let denom: String
}

// MARK: - Commercial Task Split

struct CommercialTaskSplitDTO: Codable {
    let partyID: String
    let bps: Int

    enum CodingKeys: String, CodingKey {
        case partyID = "party_id"
        case bps
    }
}

// MARK: - Commercial Task Public

struct CommercialTaskPublicDTO: Codable {
    let id: UUID
    let projectID: UUID
    let userID: UUID
    let title: String
    let budget: BudgetDTO
    let deadline: Date
    let status: CommercialTaskStatus
    let splits: [CommercialTaskSplitDTO]
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case projectID = "project_id"
        case userID = "user_id"
        case title, budget, deadline, status, splits
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum CommercialTaskStatus: String, Codable {
    case created
    case escrowFunded = "escrow_funded"
    case submissionRecorded = "submission_recorded"
    case authorizationActivated = "authorization_activated"
    case settlementReleased = "settlement_released"

    var title: String {
        switch self {
        case .created: "任务已创建"
        case .escrowFunded: "资金已托管"
        case .submissionRecorded: "作品已提交"
        case .authorizationActivated: "授权已激活"
        case .settlementReleased: "结算已释放"
        }
    }
}

// MARK: - Commercial Submission

struct CommercialSubmissionPublicDTO: Codable {
    let id: UUID
    let taskID: UUID
    let artifactID: UUID
    let artifactSHA256: String
    let deliveryURL: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case taskID = "task_id"
        case artifactID = "artifact_id"
        case artifactSHA256 = "artifact_sha256"
        case deliveryURL = "delivery_url"
        case createdAt = "created_at"
    }
}

// MARK: - Chain Transaction

struct ChainTransactionPublicDTO: Codable {
    let id: UUID
    let action: ChainTransactionAction
    let status: ChainTransactionStatus
    let network: String
    let chainID: String?
    let transactionHash: String?
    let explorerURL: String?
    let artifactSHA256: String?
    let amount: String?
    let denom: String?
    let failureReason: String?
    let retryable: Bool?
    let submittedAt: Date?
    let confirmedAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, action, status, network
        case chainID = "chain_id"
        case transactionHash = "transaction_hash"
        case explorerURL = "explorer_url"
        case artifactSHA256 = "artifact_sha256"
        case amount, denom
        case failureReason = "failure_reason"
        case retryable
        case submittedAt = "submitted_at"
        case confirmedAt = "confirmed_at"
        case createdAt = "created_at"
    }
}

enum ChainTransactionAction: String, Codable {
    case escrowFunded = "escrow_funded"
    case submissionRecorded = "submission_recorded"
    case authorizationActivated = "authorization_activated"
    case settlementReleased = "settlement_released"
}

enum ChainTransactionStatus: String, Codable {
    case prepared, broadcast, confirmed, failed
}

// MARK: - Commercial Task Proof

struct CommercialTaskProofDTO: Codable {
    let task: CommercialTaskPublicDTO
    let submissions: [CommercialSubmissionPublicDTO]
    let transactions: [ChainTransactionPublicDTO]
}

// MARK: - Request bodies

private struct CommercialTaskCreateRequest: Encodable {
    let projectID: UUID
    let title: String
    let budget: BudgetDTO
    let deadline: Date
    let splits: [CommercialTaskSplitDTO]

    enum CodingKeys: String, CodingKey {
        case projectID = "project_id"
        case title, budget, deadline, splits
    }
}

private struct CommercialSubmissionCreateRequest: Encodable {
    let artifactID: UUID
    let artifactSHA256: String
    let deliveryURL: String

    enum CodingKeys: String, CodingKey {
        case artifactID = "artifact_id"
        case artifactSHA256 = "artifact_sha256"
        case deliveryURL = "delivery_url"
    }
}

// MARK: - Commercial Task API

enum CommercialTaskAPI {
    /// Create a commercial task on the Injective chain.
    static func create(
        projectID: UUID,
        title: String,
        budget: BudgetDTO,
        deadline: Date,
        splits: [CommercialTaskSplitDTO],
        accessToken: String
    ) async throws -> CommercialTaskPublicDTO {
        let body = try BackendJSON.encoder.encode(
            CommercialTaskCreateRequest(
                projectID: projectID,
                title: title,
                budget: budget,
                deadline: deadline,
                splits: splits
            )
        )
        return try await APIClient.shared.send(
            "commercial-tasks",
            method: "POST",
            body: body,
            accessToken: accessToken,
            idempotencyKey: UUID().uuidString
        )
    }

    /// Submit an artifact to a commercial task.
    static func submit(
        taskID: UUID,
        artifactID: UUID,
        artifactSHA256: String,
        deliveryURL: String,
        accessToken: String
    ) async throws -> CommercialSubmissionPublicDTO {
        let body = try BackendJSON.encoder.encode(
            CommercialSubmissionCreateRequest(
                artifactID: artifactID,
                artifactSHA256: artifactSHA256,
                deliveryURL: deliveryURL
            )
        )
        return try await APIClient.shared.send(
            "commercial-tasks/\(taskID.uuidString)/submissions",
            method: "POST",
            body: body,
            accessToken: accessToken,
            idempotencyKey: UUID().uuidString
        )
    }

    /// Authorize settlement for a commercial task.
    static func authorize(
        taskID: UUID,
        accessToken: String
    ) async throws -> CommercialTaskPublicDTO {
        return try await APIClient.shared.send(
            "commercial-tasks/\(taskID.uuidString)/authorize",
            method: "POST",
            accessToken: accessToken,
            idempotencyKey: UUID().uuidString
        )
    }

    /// Trigger settlement release for a commercial task.
    static func settle(
        taskID: UUID,
        accessToken: String
    ) async throws -> CommercialTaskPublicDTO {
        return try await APIClient.shared.send(
            "commercial-tasks/\(taskID.uuidString)/settle",
            method: "POST",
            accessToken: accessToken,
            idempotencyKey: UUID().uuidString
        )
    }

    /// Read the full proof (task + submissions + chain transactions).
    static func proof(
        taskID: UUID,
        accessToken: String
    ) async throws -> CommercialTaskProofDTO {
        return try await APIClient.shared.send(
            "commercial-tasks/\(taskID.uuidString)/proof",
            accessToken: accessToken
        )
    }
}
