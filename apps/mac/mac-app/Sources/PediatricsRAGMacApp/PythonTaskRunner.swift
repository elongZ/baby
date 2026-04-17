import Foundation

final class PythonTaskRunner {
    func run(module: String, arguments: [String], projectRoot: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.currentDirectoryURL = projectRoot
            let pythonURL = preferredPythonURL(projectRoot: projectRoot)
            task.executableURL = pythonURL
            task.arguments = ["-m", module] + arguments

            var environment = ProcessInfo.processInfo.environment
            environment["BABY_APP_PROJECT_ROOT"] = projectRoot.path
            environment["PYTHONUNBUFFERED"] = "1"
            task.environment = environment

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe

            task.terminationHandler = { process in
                let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let combined = [stdout, stderr]
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .joined(separator: "\n")

                if process.terminationStatus == 0 {
                    continuation.resume(returning: combined)
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "PythonTaskRunner",
                        code: Int(process.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: combined.isEmpty ? "Python task failed." : combined]
                    ))
                }
            }

            do {
                try task.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func preferredPythonURL(projectRoot: URL) -> URL {
        let candidates = [
            projectRoot.appendingPathComponent(".venv-train/bin/python"),
            projectRoot.appendingPathComponent(".venv/bin/python"),
            URL(fileURLWithPath: "/opt/homebrew/bin/python3"),
            URL(fileURLWithPath: "/usr/bin/python3"),
        ]

        let fileManager = FileManager.default
        for candidate in candidates where fileManager.isExecutableFile(atPath: candidate.path) {
            return candidate
        }

        return URL(fileURLWithPath: "/usr/bin/python3")
    }
}
