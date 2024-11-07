import ArgumentParser
import Foundation

enum Platform: String, CaseIterable {
    case macOS
    case iOS
    case tvOS

    var destinationStrategy: DestinationStrategy {
        switch self {
        case .macOS:
            .fixed(platform: "macOS")
        case .iOS:
            .lookup(destinationPredicate: .init(runtime: "iOS-18-0", deviceType: "iPhone-16"))
        case .tvOS:
            .lookup(destinationPredicate: .init(runtime: "tvOS-18-0", deviceType: "Apple-TV-4K-3rd-generation-4K"))
        }
    }

    /// Determines which `destination` argument should be passed to `xcodebuild` for this platform.
    ///
    /// It does this by finding a simulator device matching the device type and OS version that we wish to use for this platform.
    @available(macOS 14, *)
    func resolve() async throws -> DestinationSpecifier {
        switch destinationStrategy {
        case let .fixed(platform):
            .platform(platform)
        case let .lookup(destinationPredicate):
            try await .deviceID(DestinationFetcher.fetchDeviceUDID(destinationPredicate: destinationPredicate))
        }
    }
}

extension Platform: ExpressibleByArgument {
    init?(argument: String) {
        self.init(rawValue: argument)
    }
}
