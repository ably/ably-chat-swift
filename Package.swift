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
            /*
                The upcoming ably-cocoa 1.2.37 will revert a change on which the Chat SDK depends. It will not be possible to make a single version of the Chat SDK work with ably-cocoa versions 1.2.36 and 1.2.37.

                So, in order to make sure that the Chat SDK continues to work once ably-cocoa 1.2.37 is released, let's temporarily lock the ably-cocoa dependency to 1.2.36, and release a new version of the Chat SDK. Then, once ably-cocoa 1.2.37 is released, we can release another version of the Chat SDK that requires 1.2.37 and above.
                 */
            exact: "1.2.36"
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
