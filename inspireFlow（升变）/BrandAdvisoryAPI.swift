import Foundation

// MARK: - Brand Advisory DTOs

struct AdvisoryReportDTO: Decodable {
    let evidenceStatus: String
    let brand: AdvisoryBrandDTO
    let projectContext: AdvisoryProjectContextDTO?
    let researchScope: AdvisoryResearchScopeDTO
    let evidence: [AdvisoryEvidenceDTO]
    let recommendations: [AdvisoryRecommendationDTO]
    let caveats: [String]
    let nextResearchSteps: [String]

    enum CodingKeys: String, CodingKey {
        case evidenceStatus = "evidence_status"
        case brand
        case projectContext = "project_context"
        case researchScope = "research_scope"
        case evidence, recommendations, caveats
        case nextResearchSteps = "next_research_steps"
    }
}

struct AdvisoryBrandDTO: Decodable {
    let id: UUID
    let name: String
    let description: String?
}

struct AdvisoryProjectContextDTO: Decodable {
    let id: UUID?
    let title: String?
    let type: String?
    let audience: String?
    let summary: String?
}

struct AdvisoryResearchScopeDTO: Decodable {
    let market: String
    let focusTopics: [String]
    let lookbackDays: Int
    let searchQueries: [String]

    enum CodingKeys: String, CodingKey {
        case market
        case focusTopics = "focus_topics"
        case lookbackDays = "lookback_days"
        case searchQueries = "search_queries"
    }
}

struct AdvisoryEvidenceDTO: Decodable {
    let id: String
    let title: String
    let url: String?
    let sourceDomain: String?
    let summary: String?
    let projectRelevance: String?
    let fetchedAt: Date?
    let verificationLevel: String?
    let publishedAt: Date?
    let freshness: String?

    enum CodingKeys: String, CodingKey {
        case id, title, url
        case sourceDomain = "source_domain"
        case summary
        case projectRelevance = "project_relevance"
        case fetchedAt = "fetched_at"
        case verificationLevel = "verification_level"
        case publishedAt = "published_at"
        case freshness
    }
}

struct AdvisoryRecommendationDTO: Decodable {
    let priority: String
    let actionWindow: String?
    let action: String
    let expectedEffect: String?
    let evidenceIds: [String]
    let observedFacts: [String]?
    let projectImplications: String?
    let rationale: String?
    let risks: [String]?
    let counterpoints: [String]?
    let assumptions: [String]?
    let confidence: String?

    enum CodingKeys: String, CodingKey {
        case priority
        case actionWindow = "action_window"
        case action
        case expectedEffect = "expected_effect"
        case evidenceIds = "evidence_ids"
        case observedFacts = "observed_facts"
        case projectImplications = "project_implications"
        case rationale, risks, counterpoints, assumptions, confidence
    }
}

private struct AdvisoryReportRequest: Encodable {
    let projectBrief: String
    let projectID: UUID?
    let market: String
    let focusTopics: [String]
    let lookbackDays: Int

    enum CodingKeys: String, CodingKey {
        case projectBrief = "project_brief"
        case projectID = "project_id"
        case market
        case focusTopics = "focus_topics"
        case lookbackDays = "lookback_days"
    }
}

// MARK: - Brand Advisory API

enum BrandAdvisoryAPI {
    static func requestReport(
        brandID: UUID,
        accessToken: String,
        projectBrief: String,
        projectID: UUID? = nil,
        market: String = "中国大陆",
        focusTopics: [String] = [],
        lookbackDays: Int = 7
    ) async throws -> AdvisoryReportDTO {
        let body = try BackendJSON.encoder.encode(
            AdvisoryReportRequest(
                projectBrief: projectBrief,
                projectID: projectID,
                market: market,
                focusTopics: focusTopics,
                lookbackDays: lookbackDays
            )
        )
        return try await APIClient.shared.send(
            "brands/\(brandID.uuidString)/advisory-reports",
            method: "POST",
            body: body,
            accessToken: accessToken,
            idempotencyKey: UUID().uuidString
        )
    }
}
