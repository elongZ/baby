import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case chat
    case knowledgeBase

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat:
            return "Chat"
        case .knowledgeBase:
            return "Knowledge Base"
        }
    }

    var systemImage: String {
        switch self {
        case .chat:
            return "bubble.left.and.bubble.right"
        case .knowledgeBase:
            return "externaldrive.badge.checkmark"
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

        let labels = [
            ("结论：", "结论"),
            ("依据：", "依据"),
            ("引用：", "引用"),
            ("提醒：", "提醒"),
        ]

        var extracted: [String: String] = [:]
        for (index, (_, shortLabel)) in labels.enumerated() {
            guard let startRange = normalized.range(of: labels[index].0) else {
                continue
            }

            let contentStart = startRange.upperBound
            var contentEnd = normalized.endIndex

            for nextIndex in labels.index(after: index)..<labels.count {
                if let nextRange = normalized.range(of: labels[nextIndex].0, range: contentStart..<normalized.endIndex) {
                    contentEnd = nextRange.lowerBound
                    break
                }
            }

            let value = normalized[contentStart..<contentEnd]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            extracted[shortLabel] = value
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
