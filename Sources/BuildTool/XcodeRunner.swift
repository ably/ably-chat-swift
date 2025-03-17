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

        /*
         Note: I was previously passing SWIFT_TREAT_WARNINGS_AS_ERRORS=YES here, but am no longer able to do so, for the following reasons:

         1. After adding a new package dependency, Xcode started trying to pass
            the Swift compiler the -suppress-warnings flag when compiling one of
            the newly-added transitive dependencies. This clashes with the
            -warnings-as-errors flag that Xcode adds when you set
            SWIFT_TREAT_WARNINGS_AS_ERRORS=YES, leading to a compiler error like

            > error: Conflicting options '-warnings-as-errors' and '-suppress-warnings' (in target 'InternalCollectionsUtilities' from project 'swift-collections')

            It’s not clear _why_ Xcode is adding this flag (see
            https://forums.swift.org/t/warnings-as-errors-in-sub-packages/70810),
            but perhaps it’s because of what I mention in point 2 below.

            It seems that there is no way to tell Xcode, when building your own
            Swift package, “treat warnings as errors, but only for my package, and
            not for its dependencies”.

         2. So, I thought that I’d try making Xcode remove the
            -suppress-warnings flag by additionally passing
            SWIFT_SUPPRESS_WARNINGS=NO, but this also doesn’t work because it turns
            out that one of our dependencies (swift-async-algorithms) actually does
            have some warnings, causing the build to fail.

         tl;dr: There doesn’t seem to be a way to treat warnings as errors when
         compiling the package from Package.swift using Xcode.

         It’s probably OK, though, because we also compile the package with SPM,
         and hopefully that will flag any warnings in CI (unless there’s some
         class of warnings I’m not aware of that only appear when compiling
         against the tvOS or iOS SDK).

         (I imagine that using .unsafeFlags(["-warnings-as-errors"]) in the
         manifest might work, but then that’d stop other people from being able
         to use us as a dependency. I suppose we could, in CI at least, do
         something like modifying the manifest as part of the build process, but
         that seems like a nuisance.)
         */

        try await ProcessRunner.run(executableName: "xcodebuild", arguments: arguments)
    }
}
