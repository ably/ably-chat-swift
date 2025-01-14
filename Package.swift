// swift-tools-version: 6.0

import PackageDescription

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
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/ably/ably-cocoa",
            from: "1.2.38"
        ),
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "1.5.0"
        ),
        .package(
            url: "https://github.com/apple/swift-async-algorithms",
            from: "1.0.1"
        ),
        .package(
            url: "https://github.com/JanGorman/Table.git",
            from: "1.1.1"
        ),
        .package(
            url: "https://github.com/apple/swift-docc-plugin",
            from: "1.0.0"
        ),
    ],
    targets: [
        .target(
            name: "AblyChat",
            dependencies: [
                .product(
                    name: "Ably",
                    package: "ably-cocoa"
                ),
                .product(
                    name: "AsyncAlgorithms",
                    package: "swift-async-algorithms"
                ),
            ]
        ),
        .testTarget(
            name: "AblyChatTests",
            dependencies: [
                "AblyChat",
                .product(
                    name: "AsyncAlgorithms",
                    package: "swift-async-algorithms"
                ),
            ],
            resources: [
                .copy("ably-common"),
            ]
        ),
        .executableTarget(
            name: "BuildTool",
            dependencies: [
                .product(
                    name: "ArgumentParser",
                    package: "swift-argument-parser"
                ),
                .product(
                    name: "AsyncAlgorithms",
                    package: "swift-async-algorithms"
                ),
                .product(
                    name: "Table",
                    package: "Table"
                ),
            ]
        ),
    ]
)
