// swift-tools-version: 5.5

import PackageDescription

let package = Package(
    name: "GuanceSDKConsumerChecks",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .executable(name: "ObjCConsumer", targets: ["ObjCConsumer"]),
        .executable(name: "SessionReplayObjCConsumer", targets: ["SessionReplayObjCConsumer"]),
        .executable(name: "SwiftConsumer", targets: ["SwiftConsumer"]),
        .executable(name: "SwiftUIConsumer", targets: ["SwiftUIConsumer"]),
    ],
    dependencies: [
        // Keep product dependency names stable across differently named worktrees.
        .package(name: "ft-sdk-ios", path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "ObjCConsumer",
            dependencies: [
                .product(name: "GuanceSDK", package: "ft-sdk-ios"),
            ]
        ),
        .executableTarget(
            name: "SessionReplayObjCConsumer",
            dependencies: [
                .product(name: "GuanceSessionReplay", package: "ft-sdk-ios"),
            ]
        ),
        .executableTarget(
            name: "SwiftConsumer",
            dependencies: [
                .product(name: "GuanceSDK", package: "ft-sdk-ios"),
            ]
        ),
        .executableTarget(
            name: "SwiftUIConsumer",
            dependencies: [
                .product(name: "GuanceSDK", package: "ft-sdk-ios"),
            ]
        ),
    ]
)
