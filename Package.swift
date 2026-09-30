// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GuanceSDK",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
    ],
    products: [
        .library(
            name: "GuanceSDK",
            targets: [
                "GuanceSDK",
                "GuanceSDKSwiftUI",
            ]
        ),
        .library(
            name: "GuanceWidgetExtension",
            targets: ["GuanceWidgetExtension"]
        ),
        .library(
            name: "GuanceSessionReplay",
            targets: ["GuanceSessionReplay"]
        ),
    ],
    dependencies: [],
    targets: [
        // MARK: - GuanceSDK
        .target(
            name: "GuanceSDK",
            dependencies: [
                "_GuanceSDKCore",
                "_AgentShared",
                "_GuanceSDKSwiftSupport",
                "_FTRUM",
                "_FTURLSessionAutoInstrumentation",
                "_FTLogger",
                "_FTBaseUtils",
                "_FTProtocol",
            ],
            path: "Sources",
            sources: [
                "Agent/Core",
                "Agent/AutoTrack",
            ],
            publicHeadersPath: "Agent/Public",
            cSettings: [
                .headerSearchPath("Agent/Core"),
                .headerSearchPath("Agent/AutoTrack"),
                .headerSearchPath("Agent/Config"),
                .headerSearchPath("Agent/ExternalData"),
                .headerSearchPath("Core/include"),
                .headerSearchPath("Core/FTRUM/Heatmap"),
                .headerSearchPath("Core/DataFilter")
            ]
        ),
        .target(
            name: "GuanceSDKSwiftUI",
            dependencies: [
                "GuanceSDK",
                "_GuanceSDKSwiftSupport",
            ],
            path: "Sources/Agent/SwiftUI",
            exclude: [
                "FTSwiftUIRUMBridge.swift",
                "FTSwiftUIViewNameExtractor.swift",
            ],
            sources: [
                "FTRUMSwiftUI.swift",
                "FTSwiftUIRUMViewModifier.swift",
            ]
        ),
        .target(
            name: "_GuanceSDKSwiftSupport",
            path: "Sources/Agent/SwiftUI",
            exclude: [
                "FTRUMSwiftUI.swift",
                "FTSwiftUIRUMViewModifier.swift",
            ],
            sources: [
                "FTSwiftUIRUMBridge.swift",
                "FTSwiftUIViewNameExtractor.swift",
            ]
        ),
        .target(
            name: "_AgentShared",
            dependencies: [
                "_FTBaseUtils",
                "_FTRUM",
                "_FTProtocol",
            ],
            path: "Sources/Agent",
            sources: ["Config", "ExternalData", "Extension"],
            publicHeadersPath: "Shared/Public"
        ),
        .target(
            name: "_FTProtocol",
            dependencies: [],
            path: "Sources/Core/Protocol",
            publicHeadersPath: "."
        ),
        .target(
            name: "_FTRUM",
            dependencies: [
                "_FTBaseUtils",
                "_FTProtocol",
            ],
            path: "Sources/Core/FTRUM",
            cSettings: [
                .headerSearchPath("Monitor"),
                .headerSearchPath("FTCrash"),
                .headerSearchPath("FTCrash/RecordingCore"),
                .headerSearchPath("FTCrash/Recording"),
                .headerSearchPath("FTCrash/Recording/Monitors"),
                .headerSearchPath("RUMCore"),
                .headerSearchPath("Heatmap")
            ]
        ),
        .target(
            name: "_FTURLSessionAutoInstrumentation",
            dependencies: [
                "_FTProtocol",
                "_FTBaseUtils",
            ],
            path: "Sources/Core/NetworkAutoInstrumentation",
            publicHeadersPath: "."
        ),
        .target(
            name: "_FTLogger",
            dependencies: [
                "_FTBaseUtils",
                "_FTProtocol",
            ],
            path: "Sources/Core/Logger",
            publicHeadersPath: "."
        ),
        .testTarget(
            name: "FTLoggerTests",
            dependencies: ["_FTLogger"],
            path: "Tests/FTLoggerTests"
        ),

        // MARK: - BaseUtils
        .target(
            name: "_FTBaseUtils",
            dependencies: ["_FTBaseUtils_Thread"],
            path: "Sources/Core/BaseUtils",
            sources: ["Base", "Swizzle"],
            publicHeadersPath: "include"
        ),
        .target(
            name: "_FTBaseUtils_Thread",
            path: "Sources/Core/BaseUtils/Thread"
        ),

        // MARK: - GuanceWidgetExtension
        .target(
            name: "GuanceWidgetExtension",
            dependencies: [
                "_AgentShared",
                "_FTRUM",
                "_FTURLSessionAutoInstrumentation",
                "_FTLogger",
            ],
            path: "Sources/WidgetExtension",
            resources: [
                .copy("../Resources/PrivacyInfo.xcprivacy"),
            ],
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("../Agent/Config"),
                .headerSearchPath("../Agent/ExternalData"),
            ]
        ),

        // MARK: - GuanceSDKCore
        .target(
            name: "_GuanceSDKCore",
            dependencies: [
                "_FTRUM",
                "_FTURLSessionAutoInstrumentation",
                "_FTLogger",
            ],
            path: "Sources",
            sources: [
                "Core/FTWKWebView",
                "Core/DataManager",
                "Core/RemoteConfig",
                "Core/DataFilter",
            ],
            resources: [
                .copy("Resources/PrivacyInfo.xcprivacy"),
            ],
            publicHeadersPath: "Core/Public",
            cSettings: [
                .headerSearchPath("Core/include"),
                .headerSearchPath("Core/DataManager/Upload"),
                .headerSearchPath("Core/DataManager/Storage"),
                .headerSearchPath("Core/DataManager/Storage/fmdb"),
                .headerSearchPath("Core/FTWKWebView/JSBridge"),
                .headerSearchPath("Core/DataFilter"),
            ]
        ),

        // MARK: - GuanceSessionReplay
        .target(
            name: "GuanceSessionReplay",
            dependencies: [
                "_GuanceSDKCore",
                "_GuanceSessionReplaySwiftUI",
            ],
            path: "Sources/SessionReplay",
            exclude: [
                "Recorder/SRWireframe/ViewTreeSnapshot/ViewsRecorder/SwiftUI",
            ],
            publicHeadersPath: "Public",
            cSettings: [
                .headerSearchPath("../.."),
                .headerSearchPath("../Core/include"),
                .headerSearchPath("."),
                .headerSearchPath("Processor/Builders"),
                .headerSearchPath("DataStore"),
                .headerSearchPath("Recorder"),
                .headerSearchPath("Recorder/Touch"),
                .headerSearchPath("Recorder/SRWireframe"),
                .headerSearchPath("Recorder/SRWireframe/ViewTreeSnapshot"),
                .headerSearchPath("Recorder/SRWireframe/ViewTreeSnapshot/ViewsRecorder"),
                .headerSearchPath("Recorder/SRWireframe/ViewTreeSnapshot/AppKitViewsRecorder"),
                .headerSearchPath("Recorder/ScreenChangeMonitor"),
                .headerSearchPath("Storage"),
                .headerSearchPath("Storage/Writer"),
                .headerSearchPath("Storage/Reader"),
                .headerSearchPath("Storage/TmpCache"),
                .headerSearchPath("TLV"),
                .headerSearchPath("Upload"),
                .headerSearchPath("Upload/Request"),
                .headerSearchPath("Utilities"),
            ]
        ),
        .target(
            name: "_GuanceSessionReplaySwiftUI",
            path: "Sources/SessionReplay/Recorder/SRWireframe/ViewTreeSnapshot/ViewsRecorder/SwiftUI"
        ),
    ]
)
