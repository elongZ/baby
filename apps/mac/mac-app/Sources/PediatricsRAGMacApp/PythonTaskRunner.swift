import Foundation

private final class TaskOutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var stdoutBuffer = Data()
    private var stderrBuffer = Data()
    private var didResume = false

    func appendStdout(_ data: Data) {
        append(data, to: \.stdoutBuffer)
    }

    func appendStderr(_ data: Data) {
        append(data, to: \.stderrBuffer)
    }

    func combinedOutput() -> String {
        lock.lock()
        defer { lock.unlock() }
        let stdout = String(data: stdoutBuffer, encoding: .utf8) ?? ""
        let stderr = String(data: stderrBuffer, encoding: .utf8) ?? ""
        return [stdout, stderr]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
    }

    func markResumed() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return false }
        didResume = true
        return true
    }

    private func append(_ data: Data, to keyPath: ReferenceWritableKeyPath<TaskOutputCollector, Data>) {
        guard !data.isEmpty else { return }
        lock.lock()
        self[keyPath: keyPath].append(data)
        lock.unlock()
    }
}

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
            task.standardInput = nil

            let collector = TaskOutputCollector()

            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                collector.appendStdout(handle.availableData)
            }

            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                collector.appendStderr(handle.availableData)
            }

            task.terminationHandler = { process in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil

                collector.appendStdout(outputPipe.fileHandleForReading.readDataToEndOfFile())
                collector.appendStderr(errorPipe.fileHandleForReading.readDataToEndOfFile())

                guard collector.markResumed() else { return }
                let combined = collector.combinedOutput()

                if process.terminationStatus == 0 {
                    continuation.resume(returning: combined)
                    return
                }

                continuation.resume(throwing: NSError(
                    domain: "PythonTaskRunner",
                    code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: combined.isEmpty ? "Python task failed." : combined]
                ))
            }

            do {
                try task.run()
            } catch {
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                if collector.markResumed() {
                    continuation.resume(throwing: error)
                }
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
