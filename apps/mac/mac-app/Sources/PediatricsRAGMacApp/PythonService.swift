import Foundation

@MainActor
final class PythonService: ObservableObject {
    private(set) var process: Process?
    private(set) var logFileURL: URL?
    private var logWriteHandle: FileHandle?

    let host: String
    let port: Int

    init(host: String = "127.0.0.1", port: Int = 8765) {
        self.host = host
        self.port = port
    }

    var baseURL: URL {
        URL(string: "http://\(host):\(port)/")!
    }

    func start(projectRoot: URL) throws {
        if let process, process.isRunning {
            return
        }

        let logFileURL = try prepareLogFile(projectRoot: projectRoot)
        let task = Process()
        task.currentDirectoryURL = projectRoot
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = [preferredPythonExecutable(), "-m", "scripts.run_local_api"]

        var environment = ProcessInfo.processInfo.environment
        environment["BABY_APP_PROJECT_ROOT"] = projectRoot.path
        environment["BABY_APP_API_HOST"] = host
        environment["BABY_APP_API_PORT"] = String(port)
        environment["PYTHONUNBUFFERED"] = "1"
        environment["HF_HUB_OFFLINE"] = "1"
        environment["TRANSFORMERS_OFFLINE"] = "1"
        environment["HF_DATASETS_OFFLINE"] = "1"
        task.environment = environment
        let handle = try FileHandle(forWritingTo: logFileURL)
        handle.seekToEndOfFile()
        task.standardOutput = handle
        task.standardError = handle
        try task.run()
        process = task
        logWriteHandle = handle
        self.logFileURL = logFileURL
    }

    private func preferredPythonExecutable() -> String {
        let candidates = [
            "/usr/local/bin/python3.11",
            "/usr/local/bin/python3.12",
            "/opt/homebrew/bin/python3.11",
            "/opt/homebrew/bin/python3.12",
            "python3",
        ]

        for candidate in candidates {
            if candidate == "python3" || FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        return "python3"
    }

    func stop() {
        if let process, process.isRunning {
            process.terminate()
        }
        try? logWriteHandle?.close()
        logWriteHandle = nil
        process = nil
    }

    func recentLogs() -> String {
        guard let logFileURL else {
            return "日志文件尚未创建。"
        }

        guard let data = try? Data(contentsOf: logFileURL),
              let content = String(data: data, encoding: .utf8) else {
            return "日志文件暂时不可读。"
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "日志文件已连接，等待输出。"
        }

        return String(trimmed.suffix(12000))
    }

    private func prepareLogFile(projectRoot: URL) throws -> URL {
        let logsDir = projectRoot.appendingPathComponent("workspace/app-logs", isDirectory: true)
        try FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        let logFileURL = logsDir.appendingPathComponent("local-api.log")
        if FileManager.default.fileExists(atPath: logFileURL.path) {
            try FileManager.default.removeItem(at: logFileURL)
        }
        FileManager.default.createFile(atPath: logFileURL.path, contents: Data())
        return logFileURL
    }
}
