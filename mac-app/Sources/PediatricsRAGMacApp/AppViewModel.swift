import AppKit
import Foundation
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

    private let service = PythonService()
    private let webService = WebService()
    private var bootTask: Task<Void, Never>?
    private var logRefreshTask: Task<Void, Never>?

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

    init() {
        start()
    }

    func start() {
        bootTask?.cancel()
        logRefreshTask?.cancel()
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
            projectRootPath = root.path
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
}
