import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppViewModel: ObservableObject {
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

    private let service = PythonService()
    private let webService = WebService()
    private var bootTask: Task<Void, Never>?
    private var logRefreshTask: Task<Void, Never>?
    private var trainingAutosaveTask: Task<Void, Never>?
    private var projectRootURL: URL?
    private var trainingStore: TrainingDataStore?

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

    init() {
        start()
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
                trainingInfoMessage = output
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

        guard let url = pickDocumentURL(allowedExtensions: ["pdf", "txt", "md"]) else {
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
        return rawValue
    }

    private func bootService() async {
        do {
            let root = try discoverProjectRoot()
            projectRootURL = root
            projectRootPath = root.path
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
            return FileManager.default.fileExists(atPath: "\(path)/api")
                && FileManager.default.fileExists(atPath: "\(path)/rag")
                && FileManager.default.fileExists(atPath: "\(path)/requirements-runtime.txt")
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
            trainingInfoMessage = "已保存 \(draft.sampleID)。"
        }
    }
}
