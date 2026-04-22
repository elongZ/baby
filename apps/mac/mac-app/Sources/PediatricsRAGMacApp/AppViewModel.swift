import AppKit
import AVFoundation
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppViewModel: ObservableObject {
    private static let supportedImportExtensions = [
        "pdf", "docx",
        "png", "jpg", "jpeg", "jp2", "webp", "gif", "bmp", "tiff",
        "txt", "md",
        "pptx", "xlsx", "xls",
        "html", "htm", "csv", "json", "xml", "epub",
    ]
    private static let iso8601FormatterWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    private static let localTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    private static let supportedVisionImageExtensions: Set<String> = ["jpg", "jpeg", "png", "bmp", "webp"]

    @Published var selectedSection: AppSection? = .chat
    @Published var question = ""
    @Published var topK = 3.0
    @Published var retrieveK = 9.0
    @Published var relevanceThreshold = 0.42
    @Published var serviceState: ServiceState = .booting("正在启动本地 Python 服务...")
    @Published var response: AskResponse?
    @Published var errorMessage = ""
    @Published var isAsking = false
    @Published var logs = ""
    @Published var projectRootPath = ""
    @Published var logFilePath = ""
    @Published var webState: ServiceState = .booting("等待本地 Web 启动...")
    @Published var documents: [DocumentRecord] = []
    @Published var vectorIndexStatus: VectorIndexStatus?
    @Published var knowledgeBaseErrorMessage = ""
    @Published var isRefreshingKnowledgeBase = false
    @Published var isRebuildingIndex = false
    @Published var isImportingDocument = false
    @Published var deletingDocumentIDs: Set<String> = []
    @Published var replacingDocumentIDs: Set<String> = []
    @Published var trainingSamples: [TrainingSample] = []
    @Published var selectedTrainingSampleID: String?
    @Published var trainingDraft: TrainingSample?
    @Published var trainingSearchText = ""
    @Published var trainingStatusFilter: TrainingSampleFilter = .all
    @Published var trainingListPage = 0
    @Published var trainingErrorMessage = ""
    @Published var trainingInfoMessage = ""
    @Published var isLoadingTrainingSamples = false
    @Published var isSavingTrainingSample = false
    @Published var isRefreshingTrainingContexts = false
    @Published var isExportingTrainingSnapshot = false
    @Published var isBuildingTrainingDataset = false
    @Published var trainingDatabasePath = ""
    @Published var trainingSnapshotPath = ""
    @Published var trainingDatasetPath = ""
    @Published var trainingAutosaveState: TrainingAutosaveState = .idle
    @Published var visionStatus: VisionStatusResponse?
    @Published var selectedVisionImagePath = ""
    @Published var visionPrediction: VisionPredictionResponse?
    @Published var visionErrorMessage = ""
    @Published var visionInfoMessage = ""
    @Published var isPickingVisionImage = false
    @Published var isRunningVisionPrediction = false
    @Published var visionDatasetSamples: [VisionDatasetSample] = []
    @Published var selectedVisionDatasetBucket: VisionDatasetBucket = .raw
    @Published var selectedVisionDatasetClassFilter: VisionDatasetClassFilter = .all
    @Published var selectedVisionDatasetSampleID: String?
    @Published var visionDatasetErrorMessage = ""
    @Published var visionEvaluationReport: VisionEvaluationReport?
    @Published var visionEvaluationErrorMessage = ""
    @Published var visionConfusionMatrixPath = ""
    @Published var visionEvaluationSamples: [VisionEvaluationSample] = []
    @Published var selectedVisionEvaluationSampleID: String?
    @Published var visionEvaluationShowErrorsOnly = true
    @Published var visionTrainingSummary: VisionTrainingSummary?
    @Published var visionTrainingConfig: [String: String] = [:]
    @Published var visionTrainingErrorMessage = ""
    @Published var visionCheckpointPath = ""
    @Published var detectionStatus: DetectionStatusResponse?
    @Published var selectedDetectionImagePath = ""
    @Published var detectionPrediction: DetectionPredictionResponse?
    @Published var detectionConfidenceThreshold = 0.25
    @Published var detectionIoUThreshold = 0.70
    @Published var detectionErrorMessage = ""
    @Published var detectionInfoMessage = ""
    @Published var isPickingDetectionImage = false
    @Published var isRunningDetectionPrediction = false
    @Published var detectionPredictionRunID = 0
    @Published var detectionDatasetSamples: [DetectionDatasetSample] = []
    @Published var selectedDetectionDatasetBucket: DetectionDatasetBucket = .train
    @Published var selectedDetectionDatasetClassFilter: DetectionDatasetClassFilter = .all
    @Published var selectedDetectionDatasetSampleID: String?
    @Published var detectionDatasetErrorMessage = ""
    @Published var detectionEvaluationSummary: DetectionEvaluationSummary?
    @Published var detectionEvaluationErrorMessage = ""
    @Published var detectionEvaluationRunDir = ""
    @Published var detectionResultsImagePath = ""
    @Published var detectionConfusionMatrixPath = ""
    @Published var detectionPrecisionRecallCurvePath = ""
    @Published var detectionValidationPreviewPaths: [String] = []
    @Published var detectionTrainingConfig: [String: String] = [:]
    @Published var detectionTrainingArgs: [String: String] = [:]
    @Published var detectionTrainingHistory: [DetectionTrainingEpoch] = []
    @Published var detectionTrainingErrorMessage = ""
    @Published var detectionTrainingEpochsInput = 20
    @Published var detectionTrainingBatchSizeInput = 4
    @Published var isRunningDetectionTraining = false
    @Published var detectionTrainingRunDir = ""
    @Published var detectionBestWeightsPath = ""
    @Published var roboticsConfig: RoboticsDemoConfig = .default
    @Published var detectionCameraConfig: [String: String] = [:]
    @Published var detectionPreprocessConfig: [String: String] = [:]
    @Published var isLaunchingDetectionCameraDemo = false
    @Published var isDetectionCameraDemoRunning = false
    @Published var detectionCameraDemoErrorMessage = ""
    @Published var liveCameraSession: AVCaptureSession?
    @Published var liveCameraFrameSize: CGSize = .zero

    private let service = PythonService()
    private let webService = WebService()
    private let detectionCameraController = DetectionCameraController()
    private var bootTask: Task<Void, Never>?
    private var logRefreshTask: Task<Void, Never>?
    private var trainingAutosaveTask: Task<Void, Never>?
    private var projectRootURL: URL?
    private var trainingStore: TrainingDataStore?
    private var hasLoadedDetectionThresholdDefaults = false
    private var hasLoadedDetectionTrainingDefaults = false
    private var isProcessingLiveDetectionFrame = false
    private var detectionAnnotationTask: Process?

    init() {
        detectionCameraController.onFrameJPEG = { [weak self] jpegData, frameSize in
            Task { @MainActor [weak self] in
                await self?.submitLiveDetectionFrame(jpegData: jpegData, frameSize: frameSize)
            }
        }
        start()
    }

    var canAsk: Bool {
        if case .ready = serviceState {
            return !isAsking
        }
        return false
    }

    var currentMetrics: String {
        guard let response else {
            return "生成模式 -   最高相关性 -   阈值 -   是否通过 -"
        }
        return String(
            format: "生成模式 %@   最高相关性 %.4f   阈值 %.2f   是否通过 %@",
            response.generationMode,
            response.bestRelevanceScore,
            response.relevanceThreshold,
            response.evidencePassed ? "true" : "false"
        )
    }

    var generationModeLabel: String {
        response?.generationMode ?? "-"
    }

    var evidencePassedLabel: String {
        guard let response else { return "-" }
        return response.evidencePassed ? "已通过" : "未通过"
    }

    var bestRelevanceLabel: String {
        guard let response else { return "-" }
        return String(format: "%.4f", response.bestRelevanceScore)
    }

    var thresholdLabel: String {
        guard let response else { return String(format: "%.2f", relevanceThreshold) }
        return String(format: "%.2f", response.relevanceThreshold)
    }

    var webURL: URL {
        webService.webURL
    }

    var webURLLabel: String {
        webService.webURL.absoluteString
    }

    var filteredTrainingSamples: [TrainingSample] {
        let search = trainingSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trainingSamples.filter { sample in
            let matchesStatus = trainingStatusFilter.status.map { sample.status == $0 } ?? true
            let matchesSearch = search.isEmpty
                || sample.sampleID.lowercased().contains(search)
                || sample.question.lowercased().contains(search)
            return matchesStatus && matchesSearch
        }
    }

    var pagedTrainingSamples: [TrainingSample] {
        let start = trainingListPage * trainingPageSize
        guard start < filteredTrainingSamples.count else { return [] }
        let end = min(start + trainingPageSize, filteredTrainingSamples.count)
        return Array(filteredTrainingSamples[start..<end])
    }

    var trainingPageCount: Int {
        max(1, Int(ceil(Double(filteredTrainingSamples.count) / Double(trainingPageSize))))
    }

    var canGoToPreviousTrainingPage: Bool {
        trainingListPage > 0
    }

    var canGoToNextTrainingPage: Bool {
        trainingListPage + 1 < trainingPageCount
    }

    var trainingPaginationLabel: String {
        guard !filteredTrainingSamples.isEmpty else { return "0 / 0" }
        return "\(trainingListPage + 1) / \(trainingPageCount)"
    }

    var selectedTrainingSample: TrainingSample? {
        guard let selectedTrainingSampleID else { return nil }
        return trainingSamples.first(where: { $0.sampleID == selectedTrainingSampleID })
    }

    var hasUnsavedTrainingChanges: Bool {
        guard let draft = trainingDraft, let selectedTrainingSample else {
            return false
        }
        return draft != selectedTrainingSample
    }

    var canMarkTrainingSampleDone: Bool {
        trainingDraft?.isComplete ?? false
    }

    var trainingCompletionIssues: [String] {
        trainingDraft?.completionIssues ?? []
    }

    var trainingSearchBinding: Binding<String> {
        Binding(
            get: { self.trainingSearchText },
            set: { newValue in
                self.trainingSearchText = newValue
                self.trainingListPage = 0
            }
        )
    }

    var trainingStatusFilterBinding: Binding<TrainingSampleFilter> {
        Binding(
            get: { self.trainingStatusFilter },
            set: { newValue in
                self.trainingStatusFilter = newValue
                self.trainingListPage = 0
            }
        )
    }

    var filteredVisionDatasetSamples: [VisionDatasetSample] {
        visionDatasetSamples.filter { sample in
            sample.bucket == selectedVisionDatasetBucket
                && (selectedVisionDatasetClassFilter == .all || sample.className == selectedVisionDatasetClassFilter.rawValue)
        }
    }

    var selectedVisionDatasetSample: VisionDatasetSample? {
        guard let selectedVisionDatasetSampleID else { return nil }
        return filteredVisionDatasetSamples.first(where: { $0.id == selectedVisionDatasetSampleID })
            ?? visionDatasetSamples.first(where: { $0.id == selectedVisionDatasetSampleID })
    }

    var visionDatasetBucketBinding: Binding<VisionDatasetBucket> {
        Binding(
            get: { self.selectedVisionDatasetBucket },
            set: { newValue in
                self.selectedVisionDatasetBucket = newValue
                self.reconcileVisionDatasetSelection()
            }
        )
    }

    var visionDatasetClassFilterBinding: Binding<VisionDatasetClassFilter> {
        Binding(
            get: { self.selectedVisionDatasetClassFilter },
            set: { newValue in
                self.selectedVisionDatasetClassFilter = newValue
                self.reconcileVisionDatasetSelection()
            }
        )
    }

    var filteredVisionEvaluationSamples: [VisionEvaluationSample] {
        visionEvaluationSamples.filter { sample in
            !visionEvaluationShowErrorsOnly || sample.isError
        }
    }

    var selectedVisionEvaluationSample: VisionEvaluationSample? {
        guard let selectedVisionEvaluationSampleID else { return nil }
        return filteredVisionEvaluationSamples.first(where: { $0.id == selectedVisionEvaluationSampleID })
            ?? visionEvaluationSamples.first(where: { $0.id == selectedVisionEvaluationSampleID })
    }

    var filteredDetectionDatasetSamples: [DetectionDatasetSample] {
        detectionDatasetSamples.filter { sample in
            guard sample.bucket == selectedDetectionDatasetBucket else { return false }
            switch selectedDetectionDatasetClassFilter {
            case .all:
                return true
            case .unlabeled:
                return sample.classNames.isEmpty
            case .diaper, .stroller, .phone:
                return sample.classNames.contains(selectedDetectionDatasetClassFilter.rawValue)
            }
        }
    }

    var selectedDetectionDatasetSample: DetectionDatasetSample? {
        guard let selectedDetectionDatasetSampleID else { return nil }
        return filteredDetectionDatasetSamples.first(where: { $0.id == selectedDetectionDatasetSampleID })
            ?? detectionDatasetSamples.first(where: { $0.id == selectedDetectionDatasetSampleID })
    }

    var detectionDatasetBucketBinding: Binding<DetectionDatasetBucket> {
        Binding(
            get: { self.selectedDetectionDatasetBucket },
            set: { newValue in
                self.selectedDetectionDatasetBucket = newValue
                self.reconcileDetectionDatasetSelection()
            }
        )
    }

    var detectionDatasetClassFilterBinding: Binding<DetectionDatasetClassFilter> {
        Binding(
            get: { self.selectedDetectionDatasetClassFilter },
            set: { newValue in
                self.selectedDetectionDatasetClassFilter = newValue
                self.reconcileDetectionDatasetSelection()
            }
        )
    }

    func start() {
        bootTask?.cancel()
        logRefreshTask?.cancel()
        trainingAutosaveTask?.cancel()
        response = nil
        errorMessage = ""
        logs = ""
        serviceState = .booting("正在启动本地 Python 服务...")
        webState = .booting("等待本地 Web 启动...")
        bootTask = Task {
            await bootService()
        }
    }

    func restartWeb() {
        Task {
            await bootWebService()
        }
    }

    func ask() {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "请输入问题后再提问。"
            return
        }

        guard case .ready = serviceState else {
            errorMessage = "本地服务尚未就绪。"
            return
        }

        isAsking = true
        errorMessage = ""

        let request = AskRequest(
            question: trimmed,
            topK: Int(topK.rounded()),
            retrieveK: Int(retrieveK.rounded()),
            relevanceThreshold: relevanceThreshold
        )

        Task {
            do {
                let payload = try await APIClient(baseURL: service.baseURL).ask(request)
                response = payload
            } catch {
                errorMessage = "提问失败：\(error.localizedDescription)"
                logs = service.recentLogs()
            }
            isAsking = false
        }
    }

    func clear() {
        question = ""
        response = nil
        errorMessage = ""
    }

    func binding<Value>(for keyPath: WritableKeyPath<TrainingSample, Value>, default defaultValue: Value) -> Binding<Value> {
        Binding(
            get: { self.trainingDraft?[keyPath: keyPath] ?? defaultValue },
            set: { newValue in
                self.updateTrainingDraft { draft in
                    draft[keyPath: keyPath] = newValue
                }
            }
        )
    }

    var trainingStatusBinding: Binding<TrainingSampleStatus> {
        Binding(
            get: { self.trainingDraft?.status ?? .draft },
            set: { newValue in
                guard self.trainingDraft != nil else { return }
                if newValue == .done && !(self.trainingDraft?.isComplete ?? false) {
                    let issues = self.trainingCompletionIssues.joined(separator: "、")
                    self.trainingErrorMessage = "当前样本不能标记为 done：\(issues)。"
                    return
                }
                self.updateTrainingDraft { draft in
                    draft.status = newValue
                }
            }
        )
    }

    func selectTrainingSample(_ sampleID: String?) {
        guard sampleID != selectedTrainingSampleID else {
            return
        }

        do {
            try persistTrainingDraftIfNeeded()
            trainingAutosaveTask?.cancel()
            trainingAutosaveState = .idle
            selectedTrainingSampleID = sampleID
            trainingDraft = trainingSamples.first(where: { $0.sampleID == sampleID })
            trainingErrorMessage = ""
        } catch {
            trainingErrorMessage = "切换样本失败：\(error.localizedDescription)"
        }
    }

    func refreshTrainingSamples(reselect sampleID: String? = nil) {
        guard let trainingStore else {
            trainingErrorMessage = "Training store 尚未初始化。"
            return
        }

        isLoadingTrainingSamples = true
        do {
            let currentSelection = sampleID ?? selectedTrainingSampleID
            trainingSamples = try trainingStore.fetchSamples()
            trainingDatabasePath = trainingStore.databasePath
            trainingSnapshotPath = trainingStore.snapshotPath
            trainingDatasetPath = trainingStore.datasetPath
            if trainingListPage >= trainingPageCount {
                trainingListPage = max(0, trainingPageCount - 1)
            }

            let resolvedSelection = currentSelection.flatMap { id in
                trainingSamples.first(where: { $0.sampleID == id })?.sampleID
            } ?? trainingSamples.first?.sampleID

            selectedTrainingSampleID = resolvedSelection
            trainingDraft = trainingSamples.first(where: { $0.sampleID == resolvedSelection })
            if !hasUnsavedTrainingChanges {
                trainingAutosaveState = .idle
            }
            trainingErrorMessage = ""
        } catch {
            trainingErrorMessage = "读取训练数据失败：\(error.localizedDescription)"
        }
        isLoadingTrainingSamples = false
    }

    func createTrainingSample() {
        guard let trainingStore else { return }

        do {
            try persistTrainingDraftIfNeeded()
            let sample = try trainingStore.createSample()
            trainingListPage = 0
            refreshTrainingSamples(reselect: sample.sampleID)
            if trainingDraft?.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                insertAnswerTemplate()
            }
            trainingInfoMessage = "已创建样本 \(sample.sampleID)。"
        } catch {
            trainingErrorMessage = "新建样本失败：\(error.localizedDescription)"
        }
    }

    func duplicateSelectedTrainingSample() {
        guard let trainingStore, let selectedTrainingSampleID else { return }

        do {
            try persistTrainingDraftIfNeeded()
            let sample = try trainingStore.duplicateSample(sampleID: selectedTrainingSampleID)
            refreshTrainingSamples(reselect: sample.sampleID)
            trainingInfoMessage = "已复制为 \(sample.sampleID)。"
        } catch {
            trainingErrorMessage = "复制样本失败：\(error.localizedDescription)"
        }
    }

    func saveTrainingSample() {
        do {
            try persistTrainingDraftIfNeeded(force: true)
        } catch {
            trainingErrorMessage = "保存样本失败：\(error.localizedDescription)"
        }
    }

    func insertAnswerTemplate(force: Bool = false) {
        guard let draft = trainingDraft else { return }

        let trimmedAnswer = draft.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !force && !trimmedAnswer.isEmpty {
            trainingErrorMessage = "答案已存在内容；如需覆盖，先清空后再插入模板。"
            return
        }

        updateTrainingDraft { draft in
            draft.answer = TrainingSample.answerTemplate
        }
        trainingInfoMessage = "已插入答案模板。"
    }

    func markSelectedTrainingSampleDone() {
        guard trainingDraft != nil else { return }
        guard canMarkTrainingSampleDone else {
            let issues = trainingCompletionIssues.joined(separator: "、")
            trainingErrorMessage = "当前样本不能标记为 done：\(issues)。"
            return
        }
        updateTrainingDraft { draft in
            draft.status = .done
        }
        saveTrainingSample()
    }

    func deleteSelectedTrainingSample() {
        guard let trainingStore, let selectedTrainingSampleID else { return }

        do {
            try trainingStore.softDeleteSample(sampleID: selectedTrainingSampleID)
            refreshTrainingSamples()
            trainingInfoMessage = "已删除样本 \(selectedTrainingSampleID)。"
        } catch {
            trainingErrorMessage = "删除样本失败：\(error.localizedDescription)"
        }
    }

    func goToPreviousTrainingPage() {
        guard canGoToPreviousTrainingPage else { return }
        trainingListPage -= 1
    }

    func goToNextTrainingPage() {
        guard canGoToNextTrainingPage else { return }
        trainingListPage += 1
    }

    func refreshSelectedTrainingContexts() {
        guard let projectRootURL, let selectedTrainingSampleID else { return }

        Task {
            do {
                trainingAutosaveTask?.cancel()
                try persistTrainingDraftIfNeeded()
                isRefreshingTrainingContexts = true
                trainingErrorMessage = ""
                let output = try await PythonTaskRunner().run(
                    module: "scripts.refresh_training_contexts",
                    arguments: [
                        "--db-path", trainingDatabasePath,
                        "--sample-id", selectedTrainingSampleID,
                        "--top-k", String(Int(topK.rounded()))
                    ],
                    projectRoot: projectRootURL
                )
                refreshTrainingSamples(reselect: selectedTrainingSampleID)
                let refreshedCount = trainingDraft?.contexts.count ?? 0
                if refreshedCount > 0 {
                    trainingInfoMessage = "已刷新 \(selectedTrainingSampleID) 的 contexts（\(refreshedCount) 条）。"
                } else {
                    let summary = output
                        .split(whereSeparator: \.isNewline)
                        .first
                        .map(String.init)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    trainingInfoMessage = summary?.isEmpty == false ? summary! : "已刷新 \(selectedTrainingSampleID) 的 contexts。"
                }
            } catch {
                trainingErrorMessage = "刷新 contexts 失败：\(error.localizedDescription)"
            }
            isRefreshingTrainingContexts = false
        }
    }

    func exportTrainingSnapshot() {
        guard let projectRootURL else { return }

        Task {
            do {
                trainingAutosaveTask?.cancel()
                try persistTrainingDraftIfNeeded()
                isExportingTrainingSnapshot = true
                trainingErrorMessage = ""
                let output = try await PythonTaskRunner().run(
                    module: "scripts.export_training_snapshot",
                    arguments: ["--db-path", trainingDatabasePath, "--output", trainingSnapshotPath],
                    projectRoot: projectRootURL
                )
                trainingInfoMessage = output
            } catch {
                trainingErrorMessage = "导出快照失败：\(error.localizedDescription)"
            }
            isExportingTrainingSnapshot = false
        }
    }

    func buildTrainingDataset() {
        guard let projectRootURL else { return }

        Task {
            do {
                trainingAutosaveTask?.cancel()
                try persistTrainingDraftIfNeeded()
                isBuildingTrainingDataset = true
                trainingErrorMessage = ""
                let output = try await PythonTaskRunner().run(
                    module: "scripts.build_sft_dataset",
                    arguments: [
                        "--input-sqlite", trainingDatabasePath,
                        "--output", trainingDatasetPath,
                        "--format", "messages"
                    ],
                    projectRoot: projectRootURL
                )
                trainingInfoMessage = output
            } catch {
                trainingErrorMessage = "生成训练集失败：\(error.localizedDescription)"
            }
            isBuildingTrainingDataset = false
        }
    }

    func refreshKnowledgeBase() {
        guard case .ready = serviceState else {
            knowledgeBaseErrorMessage = "本地 API 尚未就绪。"
            return
        }

        isRefreshingKnowledgeBase = true
        knowledgeBaseErrorMessage = ""

        Task {
            do {
                let client = APIClient(baseURL: service.baseURL)
                async let documentsTask = client.documents()
                async let indexStatusTask = client.indexStatus()
                documents = try await documentsTask
                vectorIndexStatus = try await indexStatusTask
            } catch {
                knowledgeBaseErrorMessage = "刷新 Knowledge Base 失败：\(error.localizedDescription)"
            }
            isRefreshingKnowledgeBase = false
        }
    }

    func importDocument() {
        guard case .ready = serviceState else {
            knowledgeBaseErrorMessage = "本地 API 尚未就绪。"
            return
        }

        guard let url = pickDocumentURL(allowedExtensions: Self.supportedImportExtensions) else {
            return
        }

        isImportingDocument = true
        knowledgeBaseErrorMessage = ""

        Task {
            do {
                try await APIClient(baseURL: service.baseURL).importDocument(sourcePath: url.path)
                await refreshKnowledgeBaseAfterMutation()
            } catch {
                knowledgeBaseErrorMessage = "导入资料失败：\(error.localizedDescription)"
            }
            isImportingDocument = false
        }
    }

    func deleteDocument(id: String) {
        guard case .ready = serviceState else {
            knowledgeBaseErrorMessage = "本地 API 尚未就绪。"
            return
        }

        deletingDocumentIDs.insert(id)
        isRebuildingIndex = true
        knowledgeBaseErrorMessage = ""

        Task {
            do {
                let client = APIClient(baseURL: service.baseURL)
                try await client.deleteDocument(id: id)
                vectorIndexStatus = try await client.rebuildIndex()
                documents = try await client.documents()
            } catch {
                knowledgeBaseErrorMessage = "删除资料失败：\(error.localizedDescription)"
            }
            deletingDocumentIDs.remove(id)
            isRebuildingIndex = false
        }
    }

    func replaceDocument(_ document: DocumentRecord) {
        guard case .ready = serviceState else {
            knowledgeBaseErrorMessage = "本地 API 尚未就绪。"
            return
        }

        let allowedExtension = document.extension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard let url = pickDocumentURL(allowedExtensions: [allowedExtension]) else {
            return
        }

        replacingDocumentIDs.insert(document.id)
        knowledgeBaseErrorMessage = ""

        Task {
            do {
                try await APIClient(baseURL: service.baseURL).replaceDocument(id: document.id, sourcePath: url.path)
                await refreshKnowledgeBaseAfterMutation()
            } catch {
                knowledgeBaseErrorMessage = "替换资料失败：\(error.localizedDescription)"
            }
            replacingDocumentIDs.remove(document.id)
        }
    }

    func rebuildIndex() {
        guard case .ready = serviceState else {
            knowledgeBaseErrorMessage = "本地 API 尚未就绪。"
            return
        }

        isRebuildingIndex = true
        knowledgeBaseErrorMessage = ""

        Task {
            do {
                let status = try await APIClient(baseURL: service.baseURL).rebuildIndex()
                vectorIndexStatus = status
                documents = try await APIClient(baseURL: service.baseURL).documents()
            } catch {
                knowledgeBaseErrorMessage = "重建索引失败：\(error.localizedDescription)"
            }
            isRebuildingIndex = false
        }
    }

    func isDeletingDocument(id: String) -> Bool {
        deletingDocumentIDs.contains(id)
    }

    func isReplacingDocument(id: String) -> Bool {
        replacingDocumentIDs.contains(id)
    }

    func formattedFileSize(_ size: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    func formattedTimestamp(_ rawValue: String?) -> String {
        guard let rawValue, !rawValue.isEmpty else {
            return "-"
        }

        if let date = Self.iso8601FormatterWithFractionalSeconds.date(from: rawValue)
            ?? Self.iso8601Formatter.date(from: rawValue)
        {
            return Self.localTimestampFormatter.string(from: date)
        }

        return rawValue
    }

    func selectVisionImage() {
        guard case .ready = serviceState else {
            visionErrorMessage = "本地 API 尚未就绪。"
            return
        }

        isPickingVisionImage = true
        defer { isPickingVisionImage = false }

        guard let url = pickDocumentURL(allowedExtensions: ["jpg", "jpeg", "png", "bmp", "webp"]) else {
            return
        }

        selectedVisionImagePath = url.path
        visionPrediction = nil
        visionErrorMessage = ""
        visionInfoMessage = "已选择图片：\(url.lastPathComponent)，正在开始识别..."
        runVisionPrediction()
    }

    func runVisionPrediction() {
        guard case .ready = serviceState else {
            visionErrorMessage = "本地 API 尚未就绪。"
            return
        }

        let trimmed = selectedVisionImagePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            visionErrorMessage = "请先选择一张图片。"
            return
        }

        isRunningVisionPrediction = true
        visionErrorMessage = ""
        visionInfoMessage = ""

        Task {
            do {
                let client = APIClient(baseURL: service.baseURL)
                async let predictionTask = client.predictVision(imagePath: trimmed)
                async let statusTask = client.visionStatus()
                visionPrediction = try await predictionTask
                visionStatus = try await statusTask
                visionInfoMessage = "已完成本地视觉推理。"
            } catch {
                visionErrorMessage = "Vision 推理失败：\(error.localizedDescription)"
                logs = service.recentLogs()
            }
            isRunningVisionPrediction = false
        }
    }

    func refreshVisionStatus() {
        guard case .ready = serviceState else {
            visionErrorMessage = "本地 API 尚未就绪。"
            return
        }

        Task {
            do {
                visionStatus = try await APIClient(baseURL: service.baseURL).visionStatus()
                if visionStatus?.ready == false {
                    visionInfoMessage = "Vision 模型还没准备好，请确认 checkpoint 和 prototypes 已生成。"
                }
            } catch {
                visionErrorMessage = "读取 Vision 状态失败：\(error.localizedDescription)"
            }
        }
    }

    func refreshVisionDataset() {
        guard let projectRootURL else {
            visionDatasetErrorMessage = "项目根目录尚未就绪。"
            return
        }

        do {
            let datasetRoot = projectRootURL.appendingPathComponent("vision/datasets", isDirectory: true)
            let buckets: [(VisionDatasetBucket, URL)] = [
                (.raw, datasetRoot.appendingPathComponent("raw", isDirectory: true)),
                (.train, datasetRoot.appendingPathComponent("splits/train", isDirectory: true)),
                (.val, datasetRoot.appendingPathComponent("splits/val", isDirectory: true)),
                (.test, datasetRoot.appendingPathComponent("splits/test", isDirectory: true)),
            ]

            var samples: [VisionDatasetSample] = []
            for (bucket, root) in buckets {
                for className in ["diaper", "stroller"] {
                    let classURL = root.appendingPathComponent(className, isDirectory: true)
                    guard FileManager.default.fileExists(atPath: classURL.path) else { continue }
                    let urls = try FileManager.default.contentsOfDirectory(
                        at: classURL,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles]
                    )
                    for url in urls where Self.supportedVisionImageExtensions.contains(url.pathExtension.lowercased()) {
                        samples.append(
                            VisionDatasetSample(
                                absolutePath: url.path,
                                bucket: bucket,
                                className: className,
                                name: url.lastPathComponent
                            )
                        )
                    }
                }
            }

            visionDatasetSamples = samples.sorted {
                if $0.bucket != $1.bucket {
                    return $0.bucket.rawValue < $1.bucket.rawValue
                }
                if $0.className != $1.className {
                    return $0.className < $1.className
                }
                return $0.name < $1.name
            }
            visionDatasetErrorMessage = ""
            reconcileVisionDatasetSelection()
        } catch {
            visionDatasetErrorMessage = "读取 Vision 数据集失败：\(error.localizedDescription)"
        }
    }

    func selectVisionDatasetSample(_ sampleID: String) {
        selectedVisionDatasetSampleID = sampleID
    }

    func visionDatasetCount(bucket: VisionDatasetBucket, className: String? = nil) -> Int {
        visionDatasetSamples.filter { sample in
            sample.bucket == bucket && (className == nil || sample.className == className)
        }.count
    }

    private func reconcileVisionDatasetSelection() {
        let candidates = filteredVisionDatasetSamples
        if let current = selectedVisionDatasetSampleID, candidates.contains(where: { $0.id == current }) {
            return
        }
        selectedVisionDatasetSampleID = candidates.first?.id
    }

    func refreshVisionEvaluation() {
        guard let projectRootURL else {
            visionEvaluationErrorMessage = "项目根目录尚未就绪。"
            return
        }

        do {
            let outputDir = projectRootURL.appendingPathComponent("vision/outputs/classification_run", isDirectory: true)
            let reportURL = outputDir.appendingPathComponent("classification_report.json")
            let confusionURL = outputDir.appendingPathComponent("confusion_matrix.png")

            let data = try Data(contentsOf: reportURL)
            visionEvaluationReport = try JSONDecoder().decode(VisionEvaluationReport.self, from: data)
            visionConfusionMatrixPath = FileManager.default.fileExists(atPath: confusionURL.path) ? confusionURL.path : ""
            visionEvaluationErrorMessage = ""
        } catch {
            visionEvaluationErrorMessage = "读取 Vision 评测结果失败：\(error.localizedDescription)"
        }

        guard case .ready = serviceState else { return }
        Task {
            do {
                let payload = try await APIClient(baseURL: service.baseURL).visionEvaluationSamples()
                visionEvaluationSamples = payload.samples
                reconcileVisionEvaluationSelection()
            } catch {
                visionEvaluationErrorMessage = "读取 Vision 逐样本评测失败：\(error.localizedDescription)"
            }
        }
    }

    func toggleVisionEvaluationShowErrorsOnly() {
        visionEvaluationShowErrorsOnly.toggle()
        reconcileVisionEvaluationSelection()
    }

    func selectVisionEvaluationSample(_ sampleID: String) {
        selectedVisionEvaluationSampleID = sampleID
    }

    private func reconcileVisionEvaluationSelection() {
        let candidates = filteredVisionEvaluationSamples
        if let current = selectedVisionEvaluationSampleID, candidates.contains(where: { $0.id == current }) {
            return
        }
        selectedVisionEvaluationSampleID = candidates.first?.id
    }

    func selectDetectionImage() {
        isPickingDetectionImage = true
        defer { isPickingDetectionImage = false }

        guard let url = pickDocumentURL(allowedExtensions: ["jpg", "jpeg", "png", "bmp", "webp"]) else {
            return
        }

        selectedDetectionImagePath = url.path
        detectionPrediction = nil
        detectionErrorMessage = ""
        if case .ready = serviceState {
            runDetectionPrediction()
        } else {
            detectionErrorMessage = "图片已选择，但本地 API 尚未就绪。当前实例的日志显示 8765 端口被占用，请关闭旧实例后重试。"
        }
    }

    func runRoboticsSampleDemo() {
        guard case .ready = serviceState else {
            detectionErrorMessage = "本地 API 尚未就绪。"
            return
        }

        guard let projectRootURL else {
            detectionErrorMessage = "项目根目录尚未就绪。"
            return
        }

        let candidates = [
            "detection/datasets/images/val/stroller_026.jpg",
            "detection/datasets/images/val/diaper_040.jpg",
            "detection/datasets/images/val/stroller_030.png",
            "runs/detect/detection/outputs/predict/stroller_032.jpg",
            "runs/detect/detection/outputs/predict/diaper_046.jpg",
        ]

        guard let sampleURL = candidates
            .map({ projectRootURL.appendingPathComponent($0) })
            .first(where: { FileManager.default.fileExists(atPath: $0.path) })
        else {
            detectionErrorMessage = "没有找到可用的 Robotics 演示样例图。"
            return
        }

        selectedDetectionImagePath = sampleURL.path
        detectionPrediction = nil
        detectionErrorMessage = ""
        runDetectionPrediction()
    }

    func refreshDetectionStatus() {
        guard case .ready = serviceState else {
            detectionErrorMessage = "本地 API 尚未就绪。"
            return
        }

        Task {
            do {
                let status = try await APIClient(baseURL: service.baseURL).detectionStatus()
                detectionStatus = status
                if let projectRootURL {
                    loadDetectionRuntimeConfigs(from: projectRootURL)
                }
                if !hasLoadedDetectionThresholdDefaults {
                    detectionConfidenceThreshold = status.confidenceThreshold
                    detectionIoUThreshold = status.iouThreshold
                    hasLoadedDetectionThresholdDefaults = true
                }
            } catch {
                detectionErrorMessage = "读取 Detection 状态失败：\(error.localizedDescription)"
            }
        }
    }

    func runDetectionPrediction() {
        guard case .ready = serviceState else {
            detectionErrorMessage = "本地 API 尚未就绪。"
            return
        }

        let trimmed = selectedDetectionImagePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            detectionErrorMessage = "请先选择一张图片。"
            return
        }

        isRunningDetectionPrediction = true
        detectionErrorMessage = ""

        Task {
            do {
                let client = APIClient(baseURL: service.baseURL)
                async let predictionTask = client.predictDetection(
                    imagePath: trimmed,
                    confidenceThreshold: detectionConfidenceThreshold,
                    iouThreshold: detectionIoUThreshold
                )
                async let statusTask = client.detectionStatus()
                detectionPrediction = try await predictionTask
                detectionStatus = try await statusTask
                detectionPredictionRunID += 1
            } catch {
                detectionErrorMessage = "Detection 推理失败：\(error.localizedDescription)"
                logs = service.recentLogs()
            }
            isRunningDetectionPrediction = false
        }
    }

    func launchDetectionCameraDemo() {
        guard case .ready = serviceState else {
            detectionCameraDemoErrorMessage = "本地 API 尚未就绪。"
            return
        }
        guard !isDetectionCameraDemoRunning else {
            detectionCameraDemoErrorMessage = ""
            return
        }

        isLaunchingDetectionCameraDemo = true
        detectionCameraDemoErrorMessage = ""
        Task {
            do {
                try await ensureCameraAccess()
                try detectionCameraController.start()
                liveCameraSession = detectionCameraController.session
                liveCameraFrameSize = .zero
                isDetectionCameraDemoRunning = true
            } catch {
                detectionCameraDemoErrorMessage = "启动摄像头失败：\(error.localizedDescription)"
            }
            isLaunchingDetectionCameraDemo = false
        }
    }

    func stopDetectionCameraDemo() {
        detectionCameraController.stop()
        isLaunchingDetectionCameraDemo = false
        isDetectionCameraDemoRunning = false
        liveCameraSession = nil
        liveCameraFrameSize = .zero
    }

    func refreshDetectionDataset() {
        guard let projectRootURL else {
            detectionDatasetErrorMessage = "项目根目录尚未就绪。"
            return
        }

        do {
            let datasetRoot = projectRootURL.appendingPathComponent("detection/datasets", isDirectory: true)
            let labelRoot = datasetRoot.appendingPathComponent("labels", isDirectory: true)
            let buckets: [(DetectionDatasetBucket, URL)] = [
                (.pending, datasetRoot.appendingPathComponent("images/pending", isDirectory: true)),
                (.train, datasetRoot.appendingPathComponent("images/train", isDirectory: true)),
                (.val, datasetRoot.appendingPathComponent("images/val", isDirectory: true)),
                (.test, datasetRoot.appendingPathComponent("images/test", isDirectory: true)),
                (.rejected, datasetRoot.appendingPathComponent("rejected", isDirectory: true)),
            ]
            let classLookup = ["0": "diaper", "1": "stroller", "2": "phone"]

            var samples: [DetectionDatasetSample] = []
            for (bucket, directory) in buckets {
                guard FileManager.default.fileExists(atPath: directory.path) else { continue }
                if bucket == .pending {
                    for className in ["diaper", "stroller", "phone"] {
                        let classDir = directory.appendingPathComponent(className, isDirectory: true)
                        guard FileManager.default.fileExists(atPath: classDir.path) else { continue }
                        let urls = try FileManager.default.contentsOfDirectory(
                            at: classDir,
                            includingPropertiesForKeys: nil,
                            options: [.skipsHiddenFiles]
                        )
                        for url in urls where Self.supportedVisionImageExtensions.contains(url.pathExtension.lowercased()) {
                            let labelURL = labelRoot
                                .appendingPathComponent("pending", isDirectory: true)
                                .appendingPathComponent(url.deletingPathExtension().lastPathComponent + ".txt")
                            let boxes = try parseDetectionBoxes(at: labelURL, classLookup: classLookup)
                            samples.append(
                                DetectionDatasetSample(
                                    imagePath: url.path,
                                    labelPath: FileManager.default.fileExists(atPath: labelURL.path) ? labelURL.path : nil,
                                    bucket: bucket,
                                    fileName: url.lastPathComponent,
                                    classNames: boxes.isEmpty ? [className] : Array(Set(boxes.map(\.className))).sorted(),
                                    boxes: boxes
                                )
                            )
                        }
                    }
                } else {
                    let urls = try FileManager.default.contentsOfDirectory(
                        at: directory,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles]
                    )
                    for url in urls where Self.supportedVisionImageExtensions.contains(url.pathExtension.lowercased()) {
                        let labelURL: URL? = bucket == .rejected ? nil : labelRoot
                            .appendingPathComponent(bucket.rawValue, isDirectory: true)
                            .appendingPathComponent(url.deletingPathExtension().lastPathComponent + ".txt")
                        let boxes = try parseDetectionBoxes(at: labelURL, classLookup: classLookup)
                        samples.append(
                            DetectionDatasetSample(
                                imagePath: url.path,
                                labelPath: labelURL?.path,
                                bucket: bucket,
                                fileName: url.lastPathComponent,
                                classNames: Array(Set(boxes.map(\.className))).sorted(),
                                boxes: boxes
                            )
                        )
                    }
                }
            }

            detectionDatasetSamples = samples.sorted {
                if $0.bucket != $1.bucket { return $0.bucket.rawValue < $1.bucket.rawValue }
                return $0.fileName < $1.fileName
            }
            detectionDatasetErrorMessage = ""
            reconcileDetectionDatasetSelection()
        } catch {
            detectionDatasetErrorMessage = "读取 Detection 数据集失败：\(error.localizedDescription)"
        }
    }

    func openDetectionAnnotationTool() {
        guard let projectRootURL else {
            detectionDatasetErrorMessage = "项目根目录尚未就绪。"
            return
        }

        let fileManager = FileManager.default
        let labelImgPath = "/Users/macmain/Library/Python/3.9/bin/labelImg"
        guard fileManager.isExecutableFile(atPath: labelImgPath) else {
            detectionDatasetErrorMessage = "未找到标注工具：\(labelImgPath)"
            return
        }

        let imagesPath: String
        let labelsPath: String
        switch selectedDetectionDatasetBucket {
        case .pending:
            imagesPath = projectRootURL.appendingPathComponent("detection/datasets/images/pending", isDirectory: true).path
            labelsPath = projectRootURL.appendingPathComponent("detection/datasets/labels/pending", isDirectory: true).path
        case .train:
            imagesPath = projectRootURL.appendingPathComponent("detection/datasets/images/train", isDirectory: true).path
            labelsPath = projectRootURL.appendingPathComponent("detection/datasets/labels/train", isDirectory: true).path
        case .val:
            imagesPath = projectRootURL.appendingPathComponent("detection/datasets/images/val", isDirectory: true).path
            labelsPath = projectRootURL.appendingPathComponent("detection/datasets/labels/val", isDirectory: true).path
        case .test:
            imagesPath = projectRootURL.appendingPathComponent("detection/datasets/images/test", isDirectory: true).path
            labelsPath = projectRootURL.appendingPathComponent("detection/datasets/labels/test", isDirectory: true).path
        case .rejected:
            detectionDatasetErrorMessage = "Rejected 视图不对应标准标注目录，不能直接启动标注。"
            return
        }

        let classesPath = projectRootURL.appendingPathComponent("detection/predefined_classes.txt").path
        detectionDatasetErrorMessage = ""
        try? FileManager.default.createDirectory(atPath: labelsPath, withIntermediateDirectories: true)

        let task = Process()
        task.currentDirectoryURL = projectRootURL
        task.executableURL = URL(fileURLWithPath: labelImgPath)
        task.arguments = [imagesPath, classesPath, labelsPath]
        if selectedDetectionDatasetBucket == .pending {
            task.terminationHandler = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.promoteLabeledPendingDetectionSamples()
                }
            }
        }

        do {
            try task.run()
            detectionAnnotationTask = task
        } catch {
            detectionDatasetErrorMessage = "启动标注工具失败：\(error.localizedDescription)"
        }
    }

    func reopenSelectedDetectionSampleForAnnotation() {
        guard let sample = selectedDetectionDatasetSample else {
            detectionDatasetErrorMessage = "请先选择一张图片。"
            return
        }

        selectedDetectionDatasetBucket = sample.bucket
        openDetectionAnnotationTool()
    }

    func clearSelectedDetectionAnnotation() {
        guard let sample = selectedDetectionDatasetSample else {
            detectionDatasetErrorMessage = "请先选择一张图片。"
            return
        }
        guard let labelPath = sample.labelPath, !labelPath.isEmpty else {
            detectionDatasetErrorMessage = "当前图片没有可删除的标注文件。"
            return
        }

        do {
            if FileManager.default.fileExists(atPath: labelPath) {
                try FileManager.default.removeItem(atPath: labelPath)
            }
            refreshDetectionDataset()
        } catch {
            detectionDatasetErrorMessage = "删除标注失败：\(error.localizedDescription)"
        }
    }

    func moveSelectedDetectionSampleToRejected() {
        guard let projectRootURL, let sample = selectedDetectionDatasetSample else {
            detectionDatasetErrorMessage = "请先选择一张图片。"
            return
        }
        guard sample.bucket != .rejected else {
            detectionDatasetErrorMessage = "当前图片已经在 Rejected 中。"
            return
        }

        let fileManager = FileManager.default
        let rejectedDir = projectRootURL.appendingPathComponent("detection/datasets/rejected", isDirectory: true)
        let imageSourceURL = URL(fileURLWithPath: sample.imagePath)
        let imageTargetURL = rejectedDir.appendingPathComponent(sample.fileName)

        do {
            try fileManager.createDirectory(at: rejectedDir, withIntermediateDirectories: true)

            if fileManager.fileExists(atPath: imageTargetURL.path) {
                try fileManager.removeItem(at: imageTargetURL)
            }
            try fileManager.moveItem(at: imageSourceURL, to: imageTargetURL)

            if let labelPath = sample.labelPath, !labelPath.isEmpty, fileManager.fileExists(atPath: labelPath) {
                let labelSourceURL = URL(fileURLWithPath: labelPath)
                let labelTargetURL = rejectedDir.appendingPathComponent(labelSourceURL.lastPathComponent)
                if fileManager.fileExists(atPath: labelTargetURL.path) {
                    try fileManager.removeItem(at: labelTargetURL)
                }
                try fileManager.moveItem(at: labelSourceURL, to: labelTargetURL)
            }

            selectedDetectionDatasetBucket = .rejected
            refreshDetectionDataset()
        } catch {
            detectionDatasetErrorMessage = "移到 Rejected 失败：\(error.localizedDescription)"
        }
    }

    func selectDetectionDatasetSample(_ sampleID: String) {
        selectedDetectionDatasetSampleID = sampleID
    }

    func detectionDatasetCount(bucket: DetectionDatasetBucket) -> Int {
        detectionDatasetSamples.filter { $0.bucket == bucket }.count
    }

    private func promoteLabeledPendingDetectionSamples() {
        guard let projectRootURL else {
            detectionDatasetErrorMessage = "项目根目录尚未就绪。"
            return
        }

        let fileManager = FileManager.default
        let datasetRoot = projectRootURL.appendingPathComponent("detection/datasets", isDirectory: true)
        let pendingImagesRoot = datasetRoot.appendingPathComponent("images/pending", isDirectory: true)
        let pendingLabelsRoot = datasetRoot.appendingPathComponent("labels/pending", isDirectory: true)
        let supportedClasses = ["diaper", "stroller", "phone"]
        var movedCount = 0

        do {
            for className in supportedClasses {
                let classDir = pendingImagesRoot.appendingPathComponent(className, isDirectory: true)
                guard fileManager.fileExists(atPath: classDir.path) else { continue }
                let imageURLs = try fileManager.contentsOfDirectory(
                    at: classDir,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )

                for imageURL in imageURLs where Self.supportedVisionImageExtensions.contains(imageURL.pathExtension.lowercased()) {
                    let labelURL = pendingLabelsRoot.appendingPathComponent(imageURL.deletingPathExtension().lastPathComponent + ".txt")
                    guard hasValidPendingDetectionLabel(at: labelURL) else { continue }

                    let destinationBucket = detectionDatasetSplitForPendingSample(named: imageURL.lastPathComponent)
                    let destinationImageURL = datasetRoot
                        .appendingPathComponent("images/\(destinationBucket.rawValue)", isDirectory: true)
                        .appendingPathComponent(imageURL.lastPathComponent)
                    let destinationLabelURL = datasetRoot
                        .appendingPathComponent("labels/\(destinationBucket.rawValue)", isDirectory: true)
                        .appendingPathComponent(labelURL.lastPathComponent)

                    try fileManager.createDirectory(
                        at: destinationImageURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try fileManager.createDirectory(
                        at: destinationLabelURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )

                    if fileManager.fileExists(atPath: destinationImageURL.path) {
                        try fileManager.removeItem(at: destinationImageURL)
                    }
                    if fileManager.fileExists(atPath: destinationLabelURL.path) {
                        try fileManager.removeItem(at: destinationLabelURL)
                    }

                    try fileManager.moveItem(at: imageURL, to: destinationImageURL)
                    try fileManager.moveItem(at: labelURL, to: destinationLabelURL)
                    movedCount += 1
                }
            }

            refreshDetectionDataset()
            if movedCount > 0 {
                detectionDatasetErrorMessage = ""
                detectionInfoMessage = "已自动同步 \(movedCount) 张已标注图片到 Train / Val / Test。"
            }
        } catch {
            detectionDatasetErrorMessage = "同步 Pending 标注失败：\(error.localizedDescription)"
        }
    }

    private func hasValidPendingDetectionLabel(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return false }

        let validClasses = Set(["0", "1", "2"])
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !lines.isEmpty else { return false }

        for line in lines {
            let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count == 5, validClasses.contains(parts[0]) else { return false }
            let values = parts.dropFirst().compactMap(Double.init)
            guard values.count == 4, values.allSatisfy({ (0.0 ... 1.0).contains($0) }) else { return false }
        }
        return true
    }

    private func detectionDatasetSplitForPendingSample(named fileName: String) -> DetectionDatasetBucket {
        let bucket = fileName.utf8.reduce(0) { partial, byte in
            (partial * 31 + Int(byte)) % 10
        }
        switch bucket {
        case 0:
            return .val
        case 1:
            return .test
        default:
            return .train
        }
    }

    private func parseDetectionBoxes(at url: URL?, classLookup: [String: String]) throws -> [DetectionDatasetBox] {
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return [] }
        let text = try String(contentsOf: url, encoding: .utf8)
        return text
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
                guard parts.count == 5 else { return nil }
                guard
                    let xCenter = Double(parts[1]),
                    let yCenter = Double(parts[2]),
                    let width = Double(parts[3]),
                    let height = Double(parts[4])
                else {
                    return nil
                }
                return DetectionDatasetBox(
                    className: classLookup[parts[0]] ?? parts[0],
                    xCenter: xCenter,
                    yCenter: yCenter,
                    width: width,
                    height: height
                )
            }
    }

    private func reconcileDetectionDatasetSelection() {
        let candidates = filteredDetectionDatasetSamples
        if let current = selectedDetectionDatasetSampleID, candidates.contains(where: { $0.id == current }) {
            return
        }
        selectedDetectionDatasetSampleID = candidates.first?.id
    }

    func refreshDetectionEvaluation() {
        guard let projectRootURL else {
            detectionEvaluationErrorMessage = "项目根目录尚未就绪。"
            return
        }

        do {
            let runDir = projectRootURL.appendingPathComponent("runs/detect/detection/outputs/exp1", isDirectory: true)
            let summaryURL = runDir.appendingPathComponent("evaluation_summary.json")
            let summaryData = try Data(contentsOf: summaryURL)
            detectionEvaluationSummary = try JSONDecoder().decode(DetectionEvaluationSummary.self, from: summaryData)
            detectionEvaluationRunDir = runDir.path

            func existingPath(_ name: String) -> String {
                let path = runDir.appendingPathComponent(name).path
                return FileManager.default.fileExists(atPath: path) ? path : ""
            }

            detectionResultsImagePath = existingPath("results.png")
            detectionConfusionMatrixPath = existingPath("confusion_matrix.png")
            detectionPrecisionRecallCurvePath = existingPath("BoxPR_curve.png")
            detectionValidationPreviewPaths = [
                existingPath("val_batch0_pred.jpg"),
                existingPath("val_batch1_pred.jpg"),
                existingPath("val_batch0_labels.jpg"),
                existingPath("val_batch1_labels.jpg"),
            ].filter { !$0.isEmpty }
            detectionEvaluationErrorMessage = ""
        } catch {
            detectionEvaluationErrorMessage = "读取 Detection 评测结果失败：\(error.localizedDescription)"
        }
    }

    func refreshDetectionTraining() {
        guard let projectRootURL else {
            detectionTrainingErrorMessage = "项目根目录尚未就绪。"
            return
        }

        do {
            let configURL = projectRootURL.appendingPathComponent("detection/configs/detection.yaml")
            let runDir = projectRootURL.appendingPathComponent("runs/detect/detection/outputs/exp1", isDirectory: true)
            let argsURL = runDir.appendingPathComponent("args.yaml")
            let resultsURL = runDir.appendingPathComponent("results.csv")
            let weightsURL = runDir.appendingPathComponent("weights/best.pt")

            detectionTrainingConfig = parseKeyValueYAML(try String(contentsOf: configURL, encoding: .utf8))
            detectionTrainingArgs = parseKeyValueYAML(try String(contentsOf: argsURL, encoding: .utf8))
            detectionTrainingHistory = try parseDetectionResultsCSV(from: String(contentsOf: resultsURL, encoding: .utf8))
            detectionTrainingRunDir = runDir.path
            detectionBestWeightsPath = FileManager.default.fileExists(atPath: weightsURL.path) ? weightsURL.path : ""
            if !hasLoadedDetectionTrainingDefaults {
                let epochsValue = detectionTrainingArgs["epochs"]
                    ?? detectionTrainingConfig["train.epochs"]
                    ?? detectionTrainingConfig["epochs"]
                let batchValue = detectionTrainingArgs["batch"]
                    ?? detectionTrainingConfig["train.batch_size"]
                    ?? detectionTrainingConfig["batch_size"]
                if let epochs = Int(epochsValue ?? "") {
                    detectionTrainingEpochsInput = epochs
                }
                if let batch = Int(batchValue ?? "") {
                    detectionTrainingBatchSizeInput = batch
                }
                hasLoadedDetectionTrainingDefaults = true
            }
            detectionTrainingErrorMessage = ""
        } catch {
            detectionTrainingErrorMessage = "读取 Detection 训练结果失败：\(error.localizedDescription)"
        }
    }

    func runDetectionTraining() {
        guard let projectRootURL else {
            detectionTrainingErrorMessage = "项目根目录尚未就绪。"
            return
        }

        isRunningDetectionTraining = true
        detectionTrainingErrorMessage = ""

        Task {
            do {
                _ = try await PythonTaskRunner().run(
                    module: "detection.scripts.train_detector",
                    arguments: [
                        "--epochs", String(detectionTrainingEpochsInput),
                        "--batch-size", String(detectionTrainingBatchSizeInput),
                    ],
                    projectRoot: projectRootURL
                )
                refreshDetectionTraining()
            } catch {
                detectionTrainingErrorMessage = "重新训练失败：\(error.localizedDescription)"
            }
            isRunningDetectionTraining = false
        }
    }

    func refreshVisionTraining() {
        guard let projectRootURL else {
            visionTrainingErrorMessage = "项目根目录尚未就绪。"
            return
        }

        do {
            let outputDir = projectRootURL.appendingPathComponent("vision/outputs/classification_run", isDirectory: true)
            let summaryURL = outputDir.appendingPathComponent("train_summary.json")
            let configURL = projectRootURL.appendingPathComponent("vision/configs/classification.yaml")
            let checkpointURL = outputDir.appendingPathComponent("best_model.pt")

            let summaryData = try Data(contentsOf: summaryURL)
            visionTrainingSummary = try JSONDecoder().decode(VisionTrainingSummary.self, from: summaryData)

            let configText = try String(contentsOf: configURL, encoding: .utf8)
            visionTrainingConfig = parseVisionTrainingConfig(from: configText)
            visionCheckpointPath = FileManager.default.fileExists(atPath: checkpointURL.path) ? checkpointURL.path : ""
            visionTrainingErrorMessage = ""
        } catch {
            visionTrainingErrorMessage = "读取 Vision 训练结果失败：\(error.localizedDescription)"
        }
    }

    private func parseVisionTrainingConfig(from text: String) -> [String: String] {
        var section = ""
        var values: [String: String] = [:]

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            if line.hasSuffix(":") {
                section = String(line.dropLast())
                continue
            }
            let parts = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            let key = section.isEmpty ? parts[0] : "\(section).\(parts[0])"
            values[key] = parts[1]
        }

        return values
    }

    private func parseKeyValueYAML(_ text: String) -> [String: String] {
        var section = ""
        var values: [String: String] = [:]

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            if line.hasSuffix(":") {
                section = String(line.dropLast())
                continue
            }
            let parts = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            let key = section.isEmpty ? parts[0] : "\(section).\(parts[0])"
            values[key] = parts[1]
        }

        return values
    }

    private func parseDetectionResultsCSV(from text: String) throws -> [DetectionTrainingEpoch] {
        let rows = text.split(whereSeparator: \.isNewline).map(String.init)
        guard rows.count >= 2 else { return [] }
        let headers = rows[0].split(separator: ",").map(String.init)

        func value(_ map: [String: String], _ key: String) -> Double {
            Double(map[key] ?? "") ?? 0
        }

        return rows.dropFirst().compactMap { row in
            let columns = row.split(separator: ",").map(String.init)
            guard columns.count == headers.count else { return nil }
            let map = Dictionary(uniqueKeysWithValues: zip(headers, columns))
            guard let epoch = Int(map["epoch"] ?? "") else { return nil }
            return DetectionTrainingEpoch(
                epoch: epoch,
                trainBoxLoss: value(map, "train/box_loss"),
                trainClsLoss: value(map, "train/cls_loss"),
                trainDflLoss: value(map, "train/dfl_loss"),
                precision: value(map, "metrics/precision(B)"),
                recall: value(map, "metrics/recall(B)"),
                map50: value(map, "metrics/mAP50(B)"),
                map50_95: value(map, "metrics/mAP50-95(B)"),
                valBoxLoss: value(map, "val/box_loss"),
                valClsLoss: value(map, "val/cls_loss"),
                valDflLoss: value(map, "val/dfl_loss")
            )
        }
    }

    private func bootService() async {
        do {
            let root = try discoverProjectRoot()
            projectRootURL = root
            projectRootPath = root.path
            loadRoboticsConfig(from: root)
            loadDetectionRuntimeConfigs(from: root)
            setupTrainingWorkspace(root)
            try service.start(projectRoot: root)
            logFilePath = service.logFileURL?.path ?? ""
            startRefreshingLogs()
            serviceState = .booting("本地服务已启动，正在检查健康状态...")

            let client = APIClient(baseURL: service.baseURL)
            for _ in 0..<60 {
                do {
                    _ = try await client.health()
                    serviceState = .ready
                    logs = service.recentLogs()
                    await bootWebService()
                    refreshKnowledgeBase()
                    refreshVisionStatus()
                    refreshVisionDataset()
                    refreshVisionEvaluation()
                    refreshVisionTraining()
                    refreshDetectionStatus()
                    refreshDetectionDataset()
                    refreshDetectionEvaluation()
                    refreshDetectionTraining()
                    return
                } catch {
                    try await Task.sleep(for: .milliseconds(1000))
                }
            }

            logs = service.recentLogs()
            serviceState = .failed("本地服务启动超时。")
            webState = .failed("本地 API 未就绪，Web 未启动。")
        } catch {
            logs = service.recentLogs()
            serviceState = .failed("无法启动本地 Python 服务：\(error.localizedDescription)")
            webState = .failed("本地 API 启动失败，Web 未启动。")
        }
    }

    private func bootWebService() async {
        guard case .ready = serviceState else {
            webState = .failed("本地 API 未就绪，Web 未启动。")
            return
        }

        webState = .booting("正在启动本地 Web...")

        do {
            let root = try discoverProjectRoot()
            webService.stop()
            try webService.start(projectRoot: root)

            for _ in 0..<20 {
                if await isWebReady() {
                    webState = .ready
                    return
                }
                try await Task.sleep(for: .milliseconds(500))
            }

            webState = .failed("本地 Web 启动超时。")
        } catch {
            webState = .failed("无法启动本地 Web：\(error.localizedDescription)")
        }
    }

    private func isWebReady() async -> Bool {
        var request = URLRequest(url: webURL)
        request.timeoutInterval = 2

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return false
            }
            return (200..<500).contains(http.statusCode)
        } catch {
            return false
        }
    }

    private func discoverProjectRoot() throws -> URL {
        let environment = ProcessInfo.processInfo.environment
        if let explicit = environment["BABY_APP_PROJECT_ROOT"], !explicit.isEmpty {
            return URL(fileURLWithPath: explicit)
        }

        func canonical(_ url: URL) -> URL {
            url.standardizedFileURL.resolvingSymlinksInPath()
        }

        func isProjectRoot(_ url: URL) -> Bool {
            let path = url.path
            return FileManager.default.fileExists(atPath: "\(path)/rag/api")
                && FileManager.default.fileExists(atPath: "\(path)/rag")
                && FileManager.default.fileExists(atPath: "\(path)/requirements/runtime.txt")
        }

        var candidates: [URL] = []
        let cwd = canonical(URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        let bundleURL = canonical(Bundle.main.bundleURL)
        let executableURL = canonical(URL(fileURLWithPath: CommandLine.arguments.first ?? bundleURL.path))

        candidates.append(cwd)
        candidates.append(cwd.deletingLastPathComponent())
        candidates.append(bundleURL.deletingLastPathComponent())
        candidates.append(bundleURL.deletingLastPathComponent().deletingLastPathComponent())
        candidates.append(bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent())
        candidates.append(executableURL.deletingLastPathComponent())
        candidates.append(executableURL.deletingLastPathComponent().deletingLastPathComponent())
        candidates.append(executableURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent())

        for candidate in candidates {
            if isProjectRoot(candidate) {
                return candidate
            }
        }

        throw NSError(
            domain: "PediatricsRAGMacApp",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "找不到项目根目录。请在仓库根目录运行，或设置 BABY_APP_PROJECT_ROOT。"]
        )
    }

    private func startRefreshingLogs() {
        logRefreshTask?.cancel()
        logRefreshTask = Task {
            while !Task.isCancelled {
                logs = service.recentLogs()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func loadRoboticsConfig(from root: URL) {
        let configURL = root.appendingPathComponent("robotics/configs/demo_config.json")
        do {
            let data = try Data(contentsOf: configURL)
            roboticsConfig = try JSONDecoder().decode(RoboticsDemoConfig.self, from: data)
        } catch {
            roboticsConfig = .default
        }
    }

    private func loadDetectionRuntimeConfigs(from root: URL) {
        let cameraConfigURL = root.appendingPathComponent("detection/configs/camera.yaml")
        let preprocessConfigURL = root.appendingPathComponent("detection/configs/preprocess.yaml")
        detectionCameraConfig = (try? String(contentsOf: cameraConfigURL, encoding: .utf8)).map(parseKeyValueYAML) ?? [:]
        detectionPreprocessConfig = (try? String(contentsOf: preprocessConfigURL, encoding: .utf8)).map(parseKeyValueYAML) ?? [:]
    }

    private func submitLiveDetectionFrame(jpegData: Data, frameSize: CGSize) async {
        guard isDetectionCameraDemoRunning else { return }
        guard !isProcessingLiveDetectionFrame else { return }
        guard case .ready = serviceState else { return }

        isProcessingLiveDetectionFrame = true
        liveCameraFrameSize = frameSize
        defer { isProcessingLiveDetectionFrame = false }

        do {
            let client = APIClient(baseURL: service.baseURL)
            let prediction = try await client.predictDetectionFrame(
                jpegData: jpegData,
                confidenceThreshold: detectionConfidenceThreshold,
                iouThreshold: detectionIoUThreshold
            )
            detectionPrediction = prediction
            detectionPredictionRunID += 1
            detectionErrorMessage = ""
        } catch {
            detectionCameraDemoErrorMessage = "实时检测失败：\(error.localizedDescription)"
        }
    }

    private func ensureCameraAccess() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted { return }
            fallthrough
        default:
            throw NSError(domain: "AppViewModel", code: 7001, userInfo: [
                NSLocalizedDescriptionKey: "未授予摄像头权限。"
            ])
        }
    }

    private func pickDocumentURL(allowedExtensions: [String]) -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = allowedExtensions.compactMap { UTType(filenameExtension: $0) }
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func refreshKnowledgeBaseAfterMutation() async {
        do {
            let client = APIClient(baseURL: service.baseURL)
            async let documentsTask = client.documents()
            async let indexStatusTask = client.indexStatus()
            documents = try await documentsTask
            vectorIndexStatus = try await indexStatusTask
        } catch {
            knowledgeBaseErrorMessage = "刷新 Knowledge Base 失败：\(error.localizedDescription)"
        }
    }

    private func setupTrainingWorkspace(_ projectRoot: URL) {
        do {
            let store = try TrainingDataStore(projectRoot: projectRoot)
            trainingStore = store
            trainingDatabasePath = store.databasePath
            trainingSnapshotPath = store.snapshotPath
            trainingDatasetPath = store.datasetPath
            refreshTrainingSamples()
        } catch {
            trainingErrorMessage = "初始化训练数据失败：\(error.localizedDescription)"
        }
    }

    private func updateTrainingDraft(_ mutate: (inout TrainingSample) -> Void) {
        guard var draft = trainingDraft else { return }
        mutate(&draft)
        trainingDraft = draft
        trainingInfoMessage = ""
        trainingErrorMessage = ""
        scheduleTrainingAutosave()
    }

    private func scheduleTrainingAutosave() {
        guard hasUnsavedTrainingChanges else {
            trainingAutosaveTask?.cancel()
            trainingAutosaveState = .idle
            return
        }

        trainingAutosaveTask?.cancel()
        trainingAutosaveState = .pending
        let sampleID = trainingDraft?.sampleID

        trainingAutosaveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(1200))
                guard let self else { return }
                guard !Task.isCancelled else { return }
                guard sampleID == self.trainingDraft?.sampleID else { return }
                try self.persistTrainingDraftIfNeeded(auto: true)
            } catch is CancellationError {
                return
            } catch {
                guard let self else { return }
                self.trainingAutosaveState = .failed("自动保存失败：\(error.localizedDescription)")
            }
        }
    }

    private func persistTrainingDraftIfNeeded(force: Bool = false, auto: Bool = false) throws {
        guard let trainingStore, let draft = trainingDraft else {
            return
        }
        guard force || hasUnsavedTrainingChanges else {
            return
        }

        isSavingTrainingSample = true
        if auto {
            trainingAutosaveState = .saving
        }
        defer { isSavingTrainingSample = false }
        try trainingStore.saveSample(draft)
        refreshTrainingSamples(reselect: draft.sampleID)
        if auto {
            trainingAutosaveState = .saved("已自动保存 \(draft.sampleID)。")
        } else {
            trainingAutosaveState = .saved("已保存 \(draft.sampleID)。")
        }
    }

    private let trainingPageSize = 12
}
