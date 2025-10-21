// swift-tools-version: 6.2

import PackageDescription

let commonSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("ExistentialAny"),
]

let package = Package(
    name: "AblyChat",
    platforms: [
        .macOS(.v11),
        .iOS(.v14),
        .tvOS(.v14),
    ],
    products: [
        .library(
            name: "AblyChat",
            targets: [
                "AblyChat",
            ],
        ),
    ],
    dependencies: [
        // This is the SDK's only dependency.
        .package(
            url: "https://github.com/ably/ably-cocoa",
            from: "1.2.48",
        ),

        // All of the following dependencies are only used for internal purposes (testing or build tooling).
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "1.5.0",
        ),
        .package(
            url: "https://github.com/apple/swift-async-algorithms",
            from: "1.0.1",
        ),
        .package(
            url: "https://github.com/JanGorman/Table.git",
            from: "1.1.1",
        ),
        .package(
            url: "https://github.com/apple/swift-docc-plugin",
            from: "1.0.0",
        ),
        // This is a fork of https://github.com/groue/Semaphore.
        //
        // We only use this package in our tests. We need to pin its version
        // because it's 0.x, but we don't want to clash with users who are using
        // the same library. Thus we have our own fork.
        .package(
            url: "https://github.com/ably-forks/swift-semaphore",
            exact: "0.1.0",
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-clocks",
            from: "1.0.0",
        ),
    ],
    targets: [
        .target(
            name: "AblyChat",
            dependencies: [
                .product(
                    name: "Ably",
                    package: "ably-cocoa",
                ),
            ],
            swiftSettings: commonSwiftSettings,
        ),
        .testTarget(
            name: "AblyChatTests",
            dependencies: [
                "AblyChat",
                .product(
                    name: "AsyncAlgorithms",
                    package: "swift-async-algorithms",
                ),
                .product(
                    name: "Clocks",
                    package: "swift-clocks",
                ),
                .product(
                    name: "Semaphore",
                    package: "swift-semaphore",
                ),
            ],
            resources: [
                .copy("ably-common"),
            ],
            swiftSettings: commonSwiftSettings,
        ),
        .executableTarget(
            name: "BuildTool",
            dependencies: [
                .product(
                    name: "ArgumentParser",
                    package: "swift-argument-parser",
                ),
                .product(
                    name: "AsyncAlgorithms",
                    package: "swift-async-algorithms",
                ),
                .product(
                    name: "Table",
                    package: "Table",
                ),
            ],
            swiftSettings: commonSwiftSettings,
        ),
    ],
)
