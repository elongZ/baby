import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case chat
    case knowledgeBase
    case trainingData
    case visionPlayground
    case visionDataset
    case visionTraining
    case visionEvaluation
    case detectionPlayground
    case detectionDataset
    case detectionTraining
    case detectionEvaluation

    var id: String { rawValue }

    var groupTitle: String {
        switch self {
        case .chat, .knowledgeBase, .trainingData:
            return "RAG"
        case .visionPlayground, .visionDataset, .visionTraining, .visionEvaluation:
            return "Vision"
        case .detectionPlayground, .detectionDataset, .detectionTraining, .detectionEvaluation:
            return "Detection"
        }
    }

    var title: String {
        switch self {
        case .chat:
            return "Chat"
        case .knowledgeBase:
            return "Knowledge Base"
        case .trainingData:
            return "Training Data"
        case .visionPlayground:
            return "Playground"
        case .visionDataset:
            return "Dataset"
        case .visionTraining:
            return "Training"
        case .visionEvaluation:
            return "Evaluation"
        case .detectionPlayground:
            return "Playground"
        case .detectionDataset:
            return "Dataset"
        case .detectionTraining:
            return "Training"
        case .detectionEvaluation:
            return "Evaluation"
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
        case .visionPlayground:
            return "photo.on.rectangle.angled"
        case .visionDataset:
            return "square.stack.3d.up"
        case .visionTraining:
            return "brain"
        case .visionEvaluation:
            return "chart.bar.xaxis"
        case .detectionPlayground:
            return "viewfinder"
        case .detectionDataset:
            return "shippingbox"
        case .detectionTraining:
            return "figure.run"
        case .detectionEvaluation:
            return "scope"
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
    let answerModel: String
    let loraAdapterPath: String?
    let loraAdapterName: String?
    let generationMode: String
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
        case answerModel = "answer_model"
        case loraAdapterPath = "lora_adapter_path"
        case loraAdapterName = "lora_adapter_name"
        case generationMode = "generation_mode"
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

struct VisionStatusResponse: Decodable {
    let ready: Bool
    let configPath: String
    let checkpointPath: String
    let checkpointExists: Bool
    let prototypePath: String
    let prototypeExists: Bool
    let classNames: [String]
    let imageSize: Int?
    let modelName: String?
    let rejectionMode: String
    let currentThreshold: Double
    let recommendedThreshold: Double?
    let sampleCounts: [String: Int]?

    enum CodingKeys: String, CodingKey {
        case ready
        case configPath = "config_path"
        case checkpointPath = "checkpoint_path"
        case checkpointExists = "checkpoint_exists"
        case prototypePath = "prototype_path"
        case prototypeExists = "prototype_exists"
        case classNames = "class_names"
        case imageSize = "image_size"
        case modelName = "model_name"
        case rejectionMode = "rejection_mode"
        case currentThreshold = "current_threshold"
        case recommendedThreshold = "recommended_threshold"
        case sampleCounts = "sample_counts"
    }
}

struct VisionPredictRequest: Encodable {
    let imagePath: String

    enum CodingKeys: String, CodingKey {
        case imagePath = "image_path"
    }
}

struct VisionScoredLabel: Decodable, Identifiable {
    let label: String
    let score: Double

    var id: String { label }
}

struct VisionPredictionResponse: Decodable {
    let imagePath: String
    let predictedLabel: String
    let finalLabel: String
    let accepted: Bool
    let rejectionMode: String
    let threshold: Double
    let maxProbability: Double
    let topPredictions: [VisionScoredLabel]
    let prototypeScores: [VisionScoredLabel]
    let bestSimilarity: Double?
    let bestSimilarityLabel: String?
    let explanation: String
    let concept: String

    enum CodingKeys: String, CodingKey {
        case imagePath = "image_path"
        case predictedLabel = "predicted_label"
        case finalLabel = "final_label"
        case accepted
        case rejectionMode = "rejection_mode"
        case threshold
        case maxProbability = "max_probability"
        case topPredictions = "top_predictions"
        case prototypeScores = "prototype_scores"
        case bestSimilarity = "best_similarity"
        case bestSimilarityLabel = "best_similarity_label"
        case explanation
        case concept
    }
}

struct VisionMetricsValue: Decodable {
    let precision: Double
    let recall: Double
    let f1Score: Double
    let support: Double

    enum CodingKeys: String, CodingKey {
        case precision
        case recall
        case f1Score = "f1-score"
        case support
    }
}

struct VisionEvaluationReport: Decodable {
    let diaper: VisionMetricsValue?
    let stroller: VisionMetricsValue?
    let accuracy: Double
    let macroAvg: VisionMetricsValue
    let weightedAvg: VisionMetricsValue

    enum CodingKeys: String, CodingKey {
        case diaper
        case stroller
        case accuracy
        case macroAvg = "macro avg"
        case weightedAvg = "weighted avg"
    }

    var classMetrics: [(String, VisionMetricsValue)] {
        var items: [(String, VisionMetricsValue)] = []
        if let diaper {
            items.append(("diaper", diaper))
        }
        if let stroller {
            items.append(("stroller", stroller))
        }
        return items
    }
}

struct VisionTrainingEpoch: Decodable, Identifiable {
    let epoch: Int
    let trainLoss: Double
    let trainAcc: Double
    let valLoss: Double
    let valAcc: Double

    var id: Int { epoch }

    enum CodingKeys: String, CodingKey {
        case epoch
        case trainLoss = "train_loss"
        case trainAcc = "train_acc"
        case valLoss = "val_loss"
        case valAcc = "val_acc"
    }
}

struct VisionTrainingSummary: Decodable {
    let bestValAcc: Double
    let history: [VisionTrainingEpoch]

    enum CodingKeys: String, CodingKey {
        case bestValAcc = "best_val_acc"
        case history
    }
}

struct VisionEvaluationSample: Decodable, Identifiable {
    let imagePath: String
    let fileName: String
    let trueLabel: String
    let predictedLabel: String
    let finalLabel: String
    let isError: Bool
    let accepted: Bool
    let maxProbability: Double
    let bestSimilarity: Double?
    let explanation: String

    var id: String { imagePath }

    enum CodingKeys: String, CodingKey {
        case imagePath = "image_path"
        case fileName = "file_name"
        case trueLabel = "true_label"
        case predictedLabel = "predicted_label"
        case finalLabel = "final_label"
        case isError = "is_error"
        case accepted
        case maxProbability = "max_probability"
        case bestSimilarity = "best_similarity"
        case explanation
    }
}

struct VisionEvaluationSamplesResponse: Decodable {
    let sampleCount: Int
    let errorCount: Int
    let samples: [VisionEvaluationSample]

    enum CodingKeys: String, CodingKey {
        case sampleCount = "sample_count"
        case errorCount = "error_count"
        case samples
    }
}

struct DetectionStatusResponse: Decodable {
    let ready: Bool
    let configPath: String
    let runDir: String
    let weightsPath: String
    let weightsExists: Bool
    let classNames: [String]
    let modelName: String
    let imageSize: Int
    let device: String
    let confidenceThreshold: Double
    let iouThreshold: Double

    enum CodingKeys: String, CodingKey {
        case ready
        case configPath = "config_path"
        case runDir = "run_dir"
        case weightsPath = "weights_path"
        case weightsExists = "weights_exists"
        case classNames = "class_names"
        case modelName = "model_name"
        case imageSize = "image_size"
        case device
        case confidenceThreshold = "confidence_threshold"
        case iouThreshold = "iou_threshold"
    }
}

struct DetectionPredictRequest: Encodable {
    let imagePath: String
    let confidenceThreshold: Double?
    let iouThreshold: Double?

    enum CodingKeys: String, CodingKey {
        case imagePath = "image_path"
        case confidenceThreshold = "confidence_threshold"
        case iouThreshold = "iou_threshold"
    }
}

struct DetectionBox: Decodable, Identifiable {
    let label: String
    let confidence: Double
    let box: [Double]

    var id: String {
        "\(label)-\(confidence)-\(box.map { String($0) }.joined(separator: "-"))"
    }
}

struct DetectionPredictionResponse: Decodable {
    let imagePath: String
    let renderedImagePath: String?
    let weightsPath: String
    let detectionCount: Int
    let detections: [DetectionBox]
    let explanation: String
    let concept: String

    enum CodingKeys: String, CodingKey {
        case imagePath = "image_path"
        case renderedImagePath = "rendered_image_path"
        case weightsPath = "weights_path"
        case detectionCount = "detection_count"
        case detections
        case explanation
        case concept
    }
}

enum DetectionDatasetBucket: String, CaseIterable, Identifiable {
    case train
    case val
    case test
    case rejected

    var id: String { rawValue }

    var title: String {
        switch self {
        case .train:
            return "Train"
        case .val:
            return "Val"
        case .test:
            return "Test"
        case .rejected:
            return "Rejected"
        }
    }
}

enum DetectionDatasetClassFilter: String, CaseIterable, Identifiable {
    case all
    case diaper
    case stroller
    case unlabeled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .diaper:
            return "Diaper"
        case .stroller:
            return "Stroller"
        case .unlabeled:
            return "Unlabeled"
        }
    }
}

struct DetectionDatasetBox: Identifiable, Equatable {
    let className: String
    let xCenter: Double
    let yCenter: Double
    let width: Double
    let height: Double

    var id: String {
        "\(className)-\(xCenter)-\(yCenter)-\(width)-\(height)"
    }
}

struct DetectionDatasetSample: Identifiable, Equatable {
    let imagePath: String
    let labelPath: String?
    let bucket: DetectionDatasetBucket
    let fileName: String
    let classNames: [String]
    let boxes: [DetectionDatasetBox]

    var id: String { imagePath }

    var primaryClassLabel: String {
        classNames.first ?? "unlabeled"
    }
}

struct DetectionEvaluationSummary: Decodable {
    let weights: String
    let split: String
    let map50: Double
    let map50_95: Double
    let mp: Double
    let mr: Double
}

struct DetectionTrainingEpoch: Identifiable, Equatable {
    let epoch: Int
    let trainBoxLoss: Double
    let trainClsLoss: Double
    let trainDflLoss: Double
    let precision: Double
    let recall: Double
    let map50: Double
    let map50_95: Double
    let valBoxLoss: Double
    let valClsLoss: Double
    let valDflLoss: Double

    var id: Int { epoch }
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

enum VisionDatasetBucket: String, CaseIterable, Identifiable {
    case raw
    case train
    case val
    case test

    var id: String { rawValue }

    var title: String {
        switch self {
        case .raw:
            return "Raw"
        case .train:
            return "Train"
        case .val:
            return "Val"
        case .test:
            return "Test"
        }
    }

    var directoryName: String { rawValue }
}

enum VisionDatasetClassFilter: String, CaseIterable, Identifiable {
    case all
    case diaper
    case stroller

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .diaper:
            return "Diaper"
        case .stroller:
            return "Stroller"
        }
    }
}

struct VisionDatasetSample: Identifiable, Equatable {
    let absolutePath: String
    let bucket: VisionDatasetBucket
    let className: String
    let name: String

    var id: String { absolutePath }
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
        if answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("缺少答案")
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

    static let annotationGuidelineTemplate = """
    只根据当前问题和已检索到的 contexts 写答案。
    不要补充 contexts 之外的事实，不要猜测。
    优先写简洁、直接、自然的中文回答。
    如果 contexts 不足以支持明确结论，就明确说明证据不足。
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
