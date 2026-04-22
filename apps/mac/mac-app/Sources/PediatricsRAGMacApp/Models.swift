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
    case roboticsPlayground
    case roboticsWorkflow

    var id: String { rawValue }

    var groupTitle: String {
        switch self {
        case .chat, .knowledgeBase, .trainingData:
            return "RAG"
        case .visionPlayground, .visionDataset, .visionTraining, .visionEvaluation:
            return "Vision"
        case .detectionPlayground, .detectionDataset, .detectionTraining, .detectionEvaluation:
            return "Detection"
        case .roboticsPlayground, .roboticsWorkflow:
            return "Robotics"
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
        case .roboticsPlayground:
            return "Playground"
        case .roboticsWorkflow:
            return "Workflow"
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
        case .roboticsPlayground:
            return "dot.scope.display"
        case .roboticsWorkflow:
            return "point.3.connected.trianglepath.dotted"
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

struct DetectionFramePredictRequest: Encodable {
    let imageBase64: String
    let confidenceThreshold: Double?
    let iouThreshold: Double?

    enum CodingKeys: String, CodingKey {
        case imageBase64 = "image_base64"
        case confidenceThreshold = "confidence_threshold"
        case iouThreshold = "iou_threshold"
    }
}

struct DetectionBox: Decodable, Identifiable {
    let label: String
    let confidence: Double
    let box: [Double]
    let centerX: Double?
    let centerY: Double?
    let boxWidth: Double?
    let boxHeight: Double?

    var id: String {
        "\(label)-\(confidence)-\(box.map { String($0) }.joined(separator: "-"))"
    }

    enum CodingKeys: String, CodingKey {
        case label
        case confidence
        case box
        case centerX = "center_x"
        case centerY = "center_y"
        case boxWidth = "box_width"
        case boxHeight = "box_height"
    }
}

struct DetectionPickPoint: Decodable {
    let x: Double
    let y: Double
    let method: String
}

struct DetectionRobotDecisionPayload: Decodable {
    let decisionReady: Bool
    let pickPoint: DetectionPickPoint?
    let destinationBin: String
    let planner: String
    let routeRule: String
    let selectionReason: String
    let target: DetectionBox?

    enum CodingKeys: String, CodingKey {
        case decisionReady = "decision_ready"
        case pickPoint = "pick_point"
        case destinationBin = "destination_bin"
        case planner
        case routeRule = "route_rule"
        case selectionReason = "selection_reason"
        case target
    }
}

struct DetectionPreprocessSummary: Decodable {
    let enabled: Bool
    let steps: [String]
}

struct DetectionPredictionResponse: Decodable {
    let imagePath: String?
    let renderedImagePath: String?
    let weightsPath: String
    let detectionCount: Int
    let detections: [DetectionBox]
    let explanation: String
    let concept: String
    let robotics: DetectionRobotDecisionPayload?
    let preprocess: DetectionPreprocessSummary?

    enum CodingKeys: String, CodingKey {
        case imagePath = "image_path"
        case renderedImagePath = "rendered_image_path"
        case weightsPath = "weights_path"
        case detectionCount = "detection_count"
        case detections
        case explanation
        case concept
        case robotics
        case preprocess
    }
}

struct RoboticsStageConfig: Decodable, Identifiable {
    let id: String
    let title: String
    let detail: String
    let durationSeconds: Double

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case detail
        case durationSeconds = "duration_seconds"
    }
}

struct RoboticsRouteConfig: Decodable {
    let className: String
    let destinationBin: String

    enum CodingKeys: String, CodingKey {
        case className = "class_name"
        case destinationBin = "destination_bin"
    }
}

struct RoboticsInfoCardConfig: Decodable, Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let tintHex: String
    let body: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case systemImage = "system_image"
        case tintHex = "tint_hex"
        case body
    }
}

struct RoboticsDemoConfig: Decodable {
    let mode: String
    let scenario: String
    let idleTask: String
    let taskTemplate: String
    let planner: String
    let routeRuleDescription: String
    let defaultDestinationBin: String
    let stages: [RoboticsStageConfig]
    let routes: [RoboticsRouteConfig]
    let workflowTitle: String
    let workflowSubtitle: String
    let pipelineOverviewTitle: String
    let pipelineOverviewBody: String
    let workflowSteps: [RoboticsInfoCardConfig]
    let technologyCards: [RoboticsInfoCardConfig]
    let emptyStateTitle: String
    let actionExecutionLabel: String
    let targetLockNarrativeBody: String
    let targetLockNarrativeEmpty: String
    let decisionNarrativeBody: String
    let decisionNarrativeEmpty: String
    let summaryLabels: [String: String]
    let runtimeSnapshotLabels: [String: String]
    let reasoningLabels: [String: String]
    let bilingualLabels: [String: String]

    enum CodingKeys: String, CodingKey {
        case mode
        case scenario
        case idleTask = "idle_task"
        case taskTemplate = "task_template"
        case planner
        case routeRuleDescription = "route_rule_description"
        case defaultDestinationBin = "default_destination_bin"
        case stages
        case routes
        case workflowTitle = "workflow_title"
        case workflowSubtitle = "workflow_subtitle"
        case pipelineOverviewTitle = "pipeline_overview_title"
        case pipelineOverviewBody = "pipeline_overview_body"
        case workflowSteps = "workflow_steps"
        case technologyCards = "technology_cards"
        case emptyStateTitle = "empty_state_title"
        case actionExecutionLabel = "action_execution_label"
        case targetLockNarrativeBody = "target_lock_narrative_body"
        case targetLockNarrativeEmpty = "target_lock_narrative_empty"
        case decisionNarrativeBody = "decision_narrative_body"
        case decisionNarrativeEmpty = "decision_narrative_empty"
        case summaryLabels = "summary_labels"
        case runtimeSnapshotLabels = "runtime_snapshot_labels"
        case reasoningLabels = "reasoning_labels"
        case bilingualLabels = "bilingual_labels"
    }

    static let `default` = RoboticsDemoConfig(
        mode: "Simulation",
        scenario: "Sorting Demo",
        idleTask: "Pick and Place",
        taskTemplate: "Pick {label}",
        planner: "Center-point pick with fixed bin routing",
        routeRuleDescription: "Class-based routing",
        defaultDestinationBin: "bin A",
        stages: [
            RoboticsStageConfig(id: "detect", title: "Detect", detail: "Locate object candidates in the scene.", durationSeconds: 0.6),
            RoboticsStageConfig(id: "target_lock", title: "Target Lock", detail: "Select the final target center and class.", durationSeconds: 0.6),
            RoboticsStageConfig(id: "path_plan", title: "Path Plan", detail: "Build the simulated arm route for pick-and-place.", durationSeconds: 0.7),
            RoboticsStageConfig(id: "pick", title: "Pick", detail: "Execute grasp motion in the demo timeline.", durationSeconds: 0.7),
            RoboticsStageConfig(id: "transfer", title: "Transfer", detail: "Carry the target above the destination bin.", durationSeconds: 0.55),
            RoboticsStageConfig(id: "place", title: "Place", detail: "Lower the target into the destination bin.", durationSeconds: 0.35),
            RoboticsStageConfig(id: "release", title: "Release", detail: "Open the gripper and drop the target into the bin.", durationSeconds: 0.25),
        ],
        routes: [
            RoboticsRouteConfig(className: "stroller", destinationBin: "bin B"),
            RoboticsRouteConfig(className: "phone", destinationBin: "bin C"),
            RoboticsRouteConfig(className: "diaper", destinationBin: "bin A"),
        ],
        workflowTitle: "视觉到执行流程",
        workflowSubtitle: "这页用于明确说明 OpenCV、PyTorch 和工业视觉逻辑在机械臂演示链路中的分工。",
        pipelineOverviewTitle: "Input -> OpenCV -> PyTorch -> Decision -> Robot Action",
        pipelineOverviewBody: "第一版先把这条链以应用层工作流的方式固定下来。当前还未加载完整目标结果时，Workflow 会继续显示各阶段的职责分工。",
        workflowSteps: [
            RoboticsInfoCardConfig(id: "input", title: "Input Acquisition", systemImage: "photo", tintHex: "#5C87FA", body: "加载样例图像或现场画面，形成后续视觉分析的统一输入。"),
            RoboticsInfoCardConfig(id: "opencv", title: "OpenCV Processing", systemImage: "camera.aperture", tintHex: "#3882F5", body: "完成图像读写、尺寸处理、基础预处理、检测框叠加和坐标提取。"),
            RoboticsInfoCardConfig(id: "pytorch", title: "PyTorch Inference", systemImage: "bolt.circle", tintHex: "#1FB388", body: "运行分类或检测模型，解析输出并生成目标类别、置信度和候选框。"),
            RoboticsInfoCardConfig(id: "decision", title: "Industrial Vision Logic", systemImage: "gearshape.2.fill", tintHex: "#F5943D", body: "将视觉结果转为任务流程，完成目标选择、分拣决策和阶段推进。"),
            RoboticsInfoCardConfig(id: "action", title: "Robot Action Demo", systemImage: "dot.scope.display", tintHex: "#AE75F2", body: "通过 Mission Timer、Task Stages 和执行摘要，把机械臂任务以演示方式表达出来。"),
        ],
        technologyCards: [
            RoboticsInfoCardConfig(id: "opencv", title: "OpenCV", systemImage: "camera.filters", tintHex: "#3882F5", body: "负责图像读写、预处理、结果叠加绘制与目标点位提取。"),
            RoboticsInfoCardConfig(id: "pytorch", title: "PyTorch", systemImage: "brain.filled.head.profile", tintHex: "#1FB388", body: "负责分类/检测模型推理、输出解析与置信度评分。"),
            RoboticsInfoCardConfig(id: "vision_logic", title: "Industrial Vision Logic", systemImage: "gearshape.2", tintHex: "#F5943D", body: "负责目标选择、任务编排与分拣流程模拟。"),
        ],
        emptyStateTitle: "Choose a detection image to start the robotics demo.",
        actionExecutionLabel: "Simulated pick-and-place",
        targetLockNarrativeBody: "系统优先选取置信度最高的检测框作为当前任务目标，并使用框中心点作为模拟抓取点。这个点位由检测框四个边界坐标计算得到，用于后续的 Path Plan 与 Pick 阶段展示。",
        targetLockNarrativeEmpty: "当前还没有锁定目标。运行 detection 后，这里会说明为什么选中某个框作为机械臂任务目标。",
        decisionNarrativeBody: "工业视觉逻辑当前采用规则化分拣策略：先读取 PyTorch detection 的目标类别，再根据预设路由规则映射到目标料箱。第一版先用固定 bin 路由表达执行决策，后续可以扩展为更复杂的任务编排。",
        decisionNarrativeEmpty: "当前还没有生成分拣决策。检测结果返回后，这里会解释目标类别如何映射到具体的分拣动作。",
        summaryLabels: [
            "decision": "Decision",
            "execution": "Execution",
            "result": "Result",
            "runtime": "Runtime"
        ],
        runtimeSnapshotLabels: [
            "image": "Image",
            "rendered": "Rendered",
            "target": "Target",
            "pick_point": "Pick Point",
            "decision": "Decision",
            "stage": "Stage",
            "next": "Next"
        ],
        reasoningLabels: [
            "selection": "Selection",
            "center": "Center",
            "box": "Box",
            "confidence": "Confidence",
            "input_class": "Input Class",
            "rule": "Rule",
            "output_bin": "Output Bin",
            "planner": "Planner"
        ],
        bilingualLabels: [
            "mission_timer": "任务计时 Mission Timer",
            "current_stage": "当前阶段 Current Stage",
            "next_action": "下一步 Next Action",
            "task_stages": "任务阶段 Task Stages",
            "active": "进行中 Active",
            "pending": "待执行 Pending",
            "done": "已完成 Done"
        ]
    )
}

enum DetectionDatasetBucket: String, CaseIterable, Identifiable {
    case pending
    case train
    case val
    case test
    case rejected

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending:
            return "Pending"
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
    case phone
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
        case .phone:
            return "Phone"
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
