import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case chat
    case knowledgeBase
    case trainingData

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat:
            return "Chat"
        case .knowledgeBase:
            return "Knowledge Base"
        case .trainingData:
            return "Training Data"
        }
    }

    var systemImage: String {
        switch self {
        case .chat:
            return "bubble.left.and.bubble.right"
        case .knowledgeBase:
            return "externaldrive.badge.checkmark"
        case .trainingData:
            return "square.and.pencil"
        }
    }
}

struct AskResponse: Decodable {
    let answer: String
    let contexts: [ContextChunk]
    let generationMode: String
    let bestRelevanceScore: Double
    let relevanceThreshold: Double
    let evidencePassed: Bool

    enum CodingKeys: String, CodingKey {
        case answer
        case contexts
        case generationMode = "generation_mode"
        case bestRelevanceScore = "best_relevance_score"
        case relevanceThreshold = "relevance_threshold"
        case evidencePassed = "evidence_passed"
    }

    var structuredAnswer: StructuredAnswer {
        StructuredAnswer.parse(from: answer)
    }
}

struct ContextChunk: Decodable, Identifiable {
    let chunkID: String
    let source: String?
    let page: Int?
    let text: String
    let retrievalMethod: String?
    let denseScore: Double?
    let keywordScore: Double?
    let relevanceScore: Double?

    var id: String { chunkID }

    enum CodingKeys: String, CodingKey {
        case chunkID = "chunk_id"
        case source
        case page
        case text
        case retrievalMethod = "retrieval_method"
        case denseScore = "dense_score"
        case keywordScore = "keyword_score"
        case relevanceScore = "relevance_score"
    }
}

struct HealthResponse: Decodable {
    let status: String
    let generationMode: String

    enum CodingKeys: String, CodingKey {
        case status
        case generationMode = "generation_mode"
    }
}

struct DocumentRecord: Decodable, Identifiable {
    let id: String
    let relativePath: String
    let absolutePath: String
    let name: String
    let `extension`: String
    let size: Int64
    let modifiedAt: String
    let inManifest: Bool
    let chunkCount: Int
    let lastIndexedAt: String?
    let indexStatus: String

    enum CodingKeys: String, CodingKey {
        case id
        case relativePath = "relative_path"
        case absolutePath = "absolute_path"
        case name
        case `extension`
        case size
        case modifiedAt = "modified_at"
        case inManifest = "in_manifest"
        case chunkCount = "chunk_count"
        case lastIndexedAt = "last_indexed_at"
        case indexStatus = "index_status"
    }
}

struct IndexDiffStatus: Decodable {
    let added: [String]
    let modified: [String]
    let deleted: [String]
}

struct VectorIndexStatus: Decodable {
    let sourceDir: String
    let manifestPath: String
    let chunksPath: String
    let faissIndexPath: String
    let embeddingModel: String
    let documentCount: Int
    let indexedDocumentCount: Int
    let totalChunks: Int
    let indexExists: Bool
    let chunksExists: Bool
    let manifestExists: Bool
    let indexModifiedAt: String?
    let manifestModifiedAt: String?
    let chunksModifiedAt: String?
    let lastBuildAt: String?
    let dirty: Bool
    let buildStatus: String
    let lastError: String?
    let diff: IndexDiffStatus

    enum CodingKeys: String, CodingKey {
        case sourceDir = "source_dir"
        case manifestPath = "manifest_path"
        case chunksPath = "chunks_path"
        case faissIndexPath = "faiss_index_path"
        case embeddingModel = "embedding_model"
        case documentCount = "document_count"
        case indexedDocumentCount = "indexed_document_count"
        case totalChunks = "total_chunks"
        case indexExists = "index_exists"
        case chunksExists = "chunks_exists"
        case manifestExists = "manifest_exists"
        case indexModifiedAt = "index_modified_at"
        case manifestModifiedAt = "manifest_modified_at"
        case chunksModifiedAt = "chunks_modified_at"
        case lastBuildAt = "last_build_at"
        case dirty
        case buildStatus = "build_status"
        case lastError = "last_error"
        case diff
    }
}

struct DocumentsResponse: Decodable {
    let documents: [DocumentRecord]
}

struct ImportDocumentRequest: Encodable {
    let sourcePath: String

    enum CodingKeys: String, CodingKey {
        case sourcePath = "source_path"
    }
}

struct ReplaceDocumentRequest: Encodable {
    let sourcePath: String

    enum CodingKeys: String, CodingKey {
        case sourcePath = "source_path"
    }
}

struct AskRequest {
    let question: String
    let topK: Int
    let retrieveK: Int
    let relevanceThreshold: Double
}

enum TrainingSampleMode: String, CaseIterable, Identifiable, Codable {
    case groundedAnswer = "grounded_answer"
    case insufficientEvidence = "insufficient_evidence"
    case riskRouting = "risk_routing"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .groundedAnswer:
            return "Grounded"
        case .insufficientEvidence:
            return "Insufficient"
        case .riskRouting:
            return "Risk Routing"
        }
    }
}

enum TrainingSampleStatus: String, CaseIterable, Identifiable, Codable {
    case draft
    case done
    case archived

    var id: String { rawValue }

    var title: String { rawValue.capitalized }
}

enum TrainingSampleFilter: String, CaseIterable, Identifiable {
    case all
    case draft
    case done
    case archived

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var status: TrainingSampleStatus? {
        switch self {
        case .all:
            return nil
        case .draft:
            return .draft
        case .done:
            return .done
        case .archived:
            return .archived
        }
    }
}

struct TrainingContext: Codable, Hashable, Identifiable {
    let ref: String
    let chunkID: String?
    let source: String?
    let page: Int?
    let text: String

    var id: String {
        chunkID ?? "\(ref)-\(source ?? "-")-\(page ?? -1)"
    }

    enum CodingKeys: String, CodingKey {
        case ref
        case chunkID = "chunk_id"
        case source
        case page
        case text
    }
}

struct TrainingSample: Identifiable, Codable, Equatable {
    let sampleID: String
    var question: String
    var mode: TrainingSampleMode
    var annotationGuideline: String
    var contexts: [TrainingContext]
    var answer: String
    var annotationNotes: String
    var status: TrainingSampleStatus
    var sourceType: String
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
    var version: Int

    var id: String { sampleID }

    enum CodingKeys: String, CodingKey {
        case sampleID = "sample_id"
        case question
        case mode
        case annotationGuideline = "annotation_guideline"
        case contexts
        case answer
        case annotationNotes = "annotation_notes"
        case status
        case sourceType = "source_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case version
    }

    var isComplete: Bool {
        completionIssues.isEmpty
    }

    var completionIssues: [String] {
        var issues: [String] = []
        if question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("缺少问题")
        }
        if contexts.isEmpty {
            issues.append("缺少检索上下文")
        }
        if answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("缺少答案")
        } else {
            issues.append(contentsOf: answerFormatIssues)
        }
        return issues
    }

    var answerFormatIssues: [String] {
        let structured = StructuredAnswer.parse(from: answer)
        var issues: [String] = []
        if structured.conclusion?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            issues.append("答案缺少 `Conclusion` 段落")
        }
        if structured.evidence?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            issues.append("答案缺少 `Evidence` 段落")
        }
        if structured.citations?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            issues.append("答案缺少 `Citations` 段落")
        }
        if structured.reminder?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            issues.append("答案缺少 `Risk note` 段落")
        }
        return issues
    }

    static let answerTemplate = """
    Conclusion: 
    Evidence: 
    Citations: 
    Risk note: 
    """
}

enum TrainingAutosaveState: Equatable {
    case idle
    case pending
    case saving
    case saved(String)
    case failed(String)

    var message: String? {
        switch self {
        case .idle:
            return nil
        case .pending:
            return "有未保存修改，等待自动保存。"
        case .saving:
            return "正在自动保存。"
        case .saved(let message), .failed(let message):
            return message
        }
    }
}

enum ServiceState: Equatable {
    case booting(String)
    case ready
    case failed(String)

    var message: String {
        switch self {
        case .booting(let message):
            return message
        case .ready:
            return "服务已就绪。"
        case .failed(let message):
            return message
        }
    }
}

struct StructuredAnswer {
    let conclusion: String?
    let evidence: String?
    let citations: String?
    let reminder: String?
    let rawText: String

    var hasStructuredSections: Bool {
        [conclusion, evidence, citations, reminder].contains { value in
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return false
            }
            return !trimmed.isEmpty
        }
    }

    static func parse(from text: String) -> StructuredAnswer {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return StructuredAnswer(
                conclusion: nil,
                evidence: nil,
                citations: nil,
                reminder: nil,
                rawText: ""
            )
        }

        let labels: [(aliases: [String], key: String)] = [
            (["结论：", "Conclusion:"], "结论"),
            (["依据：", "Evidence:"], "依据"),
            (["引用：", "Citations:"], "引用"),
            (["提醒：", "Risk note:"], "提醒"),
        ]

        func firstMatch(
            for aliases: [String],
            in content: String,
            range: Range<String.Index>? = nil
        ) -> (range: Range<String.Index>, alias: String)? {
            let searchRange = range ?? content.startIndex..<content.endIndex
            var best: (range: Range<String.Index>, alias: String)?
            for alias in aliases {
                guard let found = content.range(of: alias, options: [.caseInsensitive], range: searchRange) else {
                    continue
                }
                if let best, found.lowerBound >= best.range.lowerBound {
                    continue
                }
                best = (found, alias)
            }
            return best
        }

        var extracted: [String: String] = [:]
        for (index, label) in labels.enumerated() {
            guard let startMatch = firstMatch(for: label.aliases, in: normalized) else {
                continue
            }

            let contentStart = startMatch.range.upperBound
            var contentEnd = normalized.endIndex

            for nextIndex in labels.index(after: index)..<labels.count {
                if let nextMatch = firstMatch(
                    for: labels[nextIndex].aliases,
                    in: normalized,
                    range: contentStart..<normalized.endIndex
                ) {
                    contentEnd = nextMatch.range.lowerBound
                    break
                }
            }

            let value = normalized[contentStart..<contentEnd]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            extracted[label.key] = value
        }

        return StructuredAnswer(
            conclusion: extracted["结论"],
            evidence: extracted["依据"],
            citations: extracted["引用"],
            reminder: extracted["提醒"],
            rawText: normalized
        )
    }
}
