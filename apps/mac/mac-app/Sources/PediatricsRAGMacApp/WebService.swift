import Foundation

@MainActor
final class WebService: ObservableObject {
    private(set) var process: Process?

    let host: String
    let port: Int
    let apiHost: String
    let apiPort: Int

    init(
        host: String = "127.0.0.1",
        port: Int = 8501,
        apiHost: String = "127.0.0.1",
        apiPort: Int = 8765
    ) {
        self.host = host
        self.port = port
        self.apiHost = apiHost
        self.apiPort = apiPort
    }

    var webURL: URL {
        URL(string: "http://\(host):\(port)")!
    }

    var apiBaseURLString: String {
        "http://\(apiHost):\(apiPort)"
    }

    func start(projectRoot: URL) throws {
        if let process, process.isRunning {
            return
        }

        let task = Process()
        task.currentDirectoryURL = projectRoot
        let launch = try resolveLaunchConfiguration(projectRoot: projectRoot)
        task.executableURL = launch.executableURL
        task.arguments = launch.arguments

        var environment = ProcessInfo.processInfo.environment
        environment["BABY_APP_PROJECT_ROOT"] = projectRoot.path
        environment["BABY_APP_API_HOST"] = apiHost
        environment["BABY_APP_API_PORT"] = String(apiPort)
        environment["API_BASE"] = apiBaseURLString
        task.environment = environment

        try task.run()
        process = task
    }

    func stop() {
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
    }

    private func resolveLaunchConfiguration(projectRoot: URL) throws -> (executableURL: URL, arguments: [String]) {
        let fileManager = FileManager.default
        let commonCandidates = [
            projectRoot.appendingPathComponent(".venv/bin/streamlit").path,
            projectRoot.appendingPathComponent("venv/bin/streamlit").path,
            "/opt/anaconda3/bin/streamlit",
            "/opt/homebrew/bin/streamlit",
            "/usr/local/bin/streamlit",
        ]

        if let matched = commonCandidates.first(where: { fileManager.isExecutableFile(atPath: $0) }) {
            return (URL(fileURLWithPath: matched), launchArguments())
        }

        return (URL(fileURLWithPath: "/usr/bin/env"), ["streamlit"] + launchArguments())
    }

    private func launchArguments() -> [String] {
        [
            "run",
            "rag/web/app.py",
            "--server.headless",
            "true",
            "--server.address",
            host,
            "--server.port",
            String(port),
            "--browser.gatherUsageStats",
            "false",
        ]
    }
}
