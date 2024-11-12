// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "UTSChatAdapter",
    platforms: [
        .macOS(.v13),
        .iOS(.v14),
        .tvOS(.v14),
    ],
    products: [
        .executable(
            name: "UTSChatAdapter",
            targets: [
                "Adapter",
            ]
        ),
        .executable(
            name: "UTSChatAdapterGenerator",
            targets: [
                "Generator",
            ]
        ),
    ],
    dependencies: [
        .package(
            path: "../" // AblyChat
        ),
    ],
    targets: [
        .executableTarget(
            name: "Adapter",
            dependencies: [
                .product(
                    name: "AblyChat",
                    package: "ably-chat-swift"
                ),
            ]
        ),
        .executableTarget(
            name: "Generator"
        ),
    ]
)
