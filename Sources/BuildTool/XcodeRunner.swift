import Foundation

@available(macOS 14, *)
enum XcodeRunner {
    static func runXcodebuild(action: String?, configuration: Configuration? = nil, scheme: String, destination: DestinationSpecifier, testPlan: String? = nil, resultBundlePath: String? = nil) async throws {
        var arguments: [String] = []

        if let action {
            arguments.append(action)
        }

        if let configuration {
            arguments.append(contentsOf: ["-configuration", configuration.rawValue])
        }

        arguments.append(contentsOf: ["-scheme", scheme])
        arguments.append(contentsOf: ["-destination", destination.xcodebuildArgument])

        if let testPlan {
            arguments.append(contentsOf: ["-testPlan", testPlan])
        }

        if let resultBundlePath {
            arguments.append(contentsOf: ["-resultBundlePath", resultBundlePath])
        }

        try await ProcessRunner.run(executableName: "xcodebuild", arguments: arguments)
    }
}
