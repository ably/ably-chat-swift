import ArgumentParser
import Foundation

@main
@available(macOS 14, *)
struct BuildTool: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        subcommands: [
            BuildAndTestLibrary.self,
            BuildExampleApp.self,
            GenerateMatrices.self,
            Lint.self,
        ]
    )
}

@available(macOS 14, *)
struct BuildAndTestLibrary: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Build and test the AblyChat library")

    @Option var platform: Platform

    mutating func run() async throws {
        let destinationSpecifier = try await platform.resolve()
        let scheme = "AblyChat"

        try await XcodeRunner.runXcodebuild(action: nil, scheme: scheme, destination: destinationSpecifier)
        try await XcodeRunner.runXcodebuild(action: "test", scheme: scheme, destination: destinationSpecifier)
    }
}

@available(macOS 14, *)
struct BuildExampleApp: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Build the AblyChatExample example app")

    @Option var platform: Platform

    mutating func run() async throws {
        let destinationSpecifier = try await platform.resolve()

        try await XcodeRunner.runXcodebuild(action: nil, scheme: "AblyChatExample", destination: destinationSpecifier)
    }
}

struct GenerateMatrices: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate a build matrix that can be used for specifying which GitHub jobs to run",
        discussion: """
        Outputs a key=value string which, when appended to $GITHUB_OUTPUT, sets the job’s `matrix` output to a JSON object which can be used for generating builds. This allows us to make sure that our various matrix jobs use consistent parameters.

        This object has the following structure:

        {
            withoutPlatform: { tooling: Tooling }[]
            withPlatform: { tooling: Tooling, platform: PlatformArgument }[]
        }

        where Tooling is

        {
            xcodeVersion: string
        }

        and PlatformArgument is a value that can be passed as the --platform argument of the build-and-test-library or build-example-app commands.
        """
    )

    mutating func run() throws {
        let tooling = [
            [
                "xcodeVersion": "16",
            ],
        ]

        let matrix: [String: Any] = [
            "withoutPlatform": [
                "tooling": tooling,
            ],
            "withPlatform": [
                "tooling": tooling,
                "platform": Platform.allCases.map(\.rawValue),
            ],
        ]

        // I’m assuming the JSONSerialization output has no newlines
        let keyValue = try "matrix=\(String(data: JSONSerialization.data(withJSONObject: matrix), encoding: .utf8))"
        fputs("\(keyValue)\n", stderr)
        print(keyValue)
    }
}

@available(macOS 14, *)
struct Lint: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Checks code formatting and quality.")

    enum Error: Swift.Error {
        case malformedSwiftVersionFile
        case malformedPackageManifestFile
        case malformedPackageLockfile
        case mismatchedVersions(swiftVersionFileVersion: String, packageManifestFileVersion: String)
        case packageLockfilesHaveDifferentContents(paths: [String])
    }

    @Flag(name: .customLong("fix"), help: .init("Fixes linting errors where possible before linting"))
    var shouldFix = false

    mutating func run() async throws {
        if shouldFix {
            try await fix()
            try await lint()
        } else {
            try await lint()
        }
    }

    func lint() async throws {
        try await ProcessRunner.run(executableName: "mint", arguments: ["run", "swiftformat", "--lint", "."])
        try await ProcessRunner.run(executableName: "mint", arguments: ["run", "swiftlint"])
        try await ProcessRunner.run(executableName: "npm", arguments: ["run", "prettier:check"])
        try await checkSwiftVersionFile()
        try await comparePackageLockfiles()
    }

    func fix() async throws {
        try await ProcessRunner.run(executableName: "mint", arguments: ["run", "swiftformat", "."])
        try await ProcessRunner.run(executableName: "mint", arguments: ["run", "swiftlint", "--fix"])
        try await ProcessRunner.run(executableName: "npm", arguments: ["run", "prettier:fix"])
    }

    /// Checks that the Swift version specified by the `Package.swift`’s `"swift-tools-version"` matches that in the `.swift-version` file (which is used to tell SwiftFormat the minimum version of Swift supported by our code). Per [SwiftFormat#1496](https://github.com/nicklockwood/SwiftFormat/issues/1496) it’s currently our responsibility to make sure they’re kept in sync.///
    func checkSwiftVersionFile() async throws {
        async let swiftVersionFileContents = loadUTF8StringFromFile(at: ".swift-version")
        async let packageManifestFileContents = loadUTF8StringFromFile(at: "Package.swift")

        guard let swiftVersionFileMatch = try await /^(\d+\.\d+)\n$/.firstMatch(in: swiftVersionFileContents) else {
            throw Error.malformedSwiftVersionFile
        }

        let swiftVersionFileVersion = String(swiftVersionFileMatch.1)

        guard let packageManifestFileMatch = try await /^\/\/ swift-tools-version: (\d+\.\d+)\n/.firstMatch(in: packageManifestFileContents) else {
            throw Error.malformedPackageManifestFile
        }

        let packageManifestFileVersion = String(packageManifestFileMatch.1)

        if swiftVersionFileVersion != packageManifestFileVersion {
            throw Error.mismatchedVersions(
                swiftVersionFileVersion: swiftVersionFileVersion,
                packageManifestFileVersion: packageManifestFileVersion
            )
        }
    }

    /// Checks that the SPM-managed Package.resolved matches the Xcode-managed one. (I still don’t fully understand _why_ there are two files).
    ///
    /// Ignores the `originHash` property of the Packaged.resolved file, because this property seems to frequently be different between the SPM version and the Xcode version, and I don’t know enough about SPM to know what this property means or whether there’s a reproducible way to get them to match.
    func comparePackageLockfiles() async throws {
        let lockfilePaths = ["Package.resolved", "AblyChat.xcworkspace/xcshareddata/swiftpm/Package.resolved"]
        let lockfileContents = try await withThrowingTaskGroup(of: Data.self) { group in
            for lockfilePath in lockfilePaths {
                group.addTask {
                    try await loadDataFromFile(at: lockfilePath)
                }
            }

            return try await group.reduce(into: []) { accum, fileContents in
                accum.append(fileContents)
            }
        }

        // Remove the `originHash` property from the Package.resolved contents before comparing (for reasons described above).
        let lockfileContentsWeCareAbout = try lockfileContents.map { data in
            guard var dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw Error.malformedPackageLockfile
            }

            dictionary.removeValue(forKey: "originHash")

            // We use .sortedKeys to get a canonical JSON encoding for comparison.
            return try JSONSerialization.data(withJSONObject: dictionary, options: .sortedKeys)
        }

        if Set(lockfileContentsWeCareAbout).count > 1 {
            throw Error.packageLockfilesHaveDifferentContents(paths: lockfilePaths)
        }
    }

    private func loadDataFromFile(at path: String) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: .init(filePath: path))
        return data
    }

    private func loadUTF8StringFromFile(at path: String) async throws -> String {
        let data = try await loadDataFromFile(at: path)
        return try String(data: data, encoding: .utf8)
    }
}
