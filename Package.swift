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
            targets: ["GuanceSDK"]
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
                "_GuanceSDKObjC",
                "_GuanceSDKSwiftUI",
            ],
            path: "Sources/SwiftPM",
            sources: ["GuanceSDK.swift"]
        ),
        .target(
            name: "_GuanceSDKObjC",
            dependencies: [
                "_GuanceSDKCore",
                "_AgentExtension",
                "_AgentExternalData",
                "_AgentConfig",
                "_GuanceSDKSwiftUI",
            ],
            path: "Sources",
            exclude: ["Agent/Core/module.modulemap"],
            sources: [
                "Agent/Core",
                "Agent/AutoTrack",
            ],
            publicHeadersPath: "Agent/Core",
            cSettings: [
                .headerSearchPath("Agent/Core"),
                .headerSearchPath("Agent/AutoTrack"),
                .headerSearchPath("Core/FTRUM/Heatmap"),
                .headerSearchPath("Core/DataFilter")
            ]
        ),
        .target(
            name: "_GuanceSDKSwiftUI",
            path: "Sources/Agent/SwiftUI"
        ),
        .target(
            name: "_AgentConfig",
            dependencies: [
                "_FTBaseUtils",
                "_FTRUM",
                "_FTProtocol",
            ],
            path: "Sources/Agent",
            sources: ["Config"],
            publicHeadersPath: "Config"
        ),
        .target(
            name: "_AgentExternalData",
            dependencies: [
                "_FTProtocol",
                "_FTBaseUtils",
            ],
            path: "Sources/Agent/ExternalData",
            publicHeadersPath: "."
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
            name: "_AgentExtension",
            dependencies: ["_FTBaseUtils"],
            path: "Sources/Agent/Extension",
            publicHeadersPath: "."
        ),
        .target(
            name: "GuanceWidgetExtension",
            dependencies: [
                "_AgentExtension",
                "_FTRUM",
                "_FTURLSessionAutoInstrumentation",
                "_AgentExternalData",
                "_FTLogger",
                "_AgentConfig",
            ],
            path: "Sources/WidgetExtension",
            resources: [
                .copy("../Resources/PrivacyInfo.xcprivacy"),
            ],
            publicHeadersPath: "."
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
            publicHeadersPath: "Core/include",
            cSettings: [
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
