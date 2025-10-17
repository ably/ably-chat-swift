import Foundation

@available(macOS 14, *)
enum ProcessRunner {
    private static let queue = DispatchQueue(label: "ProcessRunner")

    // There's probably a better way to implement these, which doesn't involve having to use a separate dispatch queue. There's a proposal for a Subprocess API coming up in Foundation which will marry Process with Swift concurrency.

    static func run(executableName: String, arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, _>) in
            queue.async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = [executableName] + arguments

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                process.waitUntilExit()

                if process.terminationStatus != 0 {
                    continuation.resume(throwing: Error.terminatedWithExitCode(process.terminationStatus))
                    return
                }

                continuation.resume()
            }
        }
    }

    static func runAndReturnStdout(executableName: String, arguments: [String]) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = [executableName] + arguments

                let standardOutput = Pipe()
                process.standardOutput = standardOutput

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                var stdoutData = Data()
                while true {
                    do {
                        if let data = try standardOutput.fileHandleForReading.readToEnd() {
                            stdoutData.append(data)
                        } else {
                            break
                        }
                    } catch {
                        process.terminate()
                        process.waitUntilExit()
                        continuation.resume(throwing: error)
                        return
                    }
                }

                process.waitUntilExit()

                if process.terminationStatus != 0 {
                    continuation.resume(throwing: Error.terminatedWithExitCode(process.terminationStatus))
                    return
                }

                continuation.resume(returning: stdoutData)
            }
        }
    }
}
