// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GuanceSDK",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_14),
        .tvOS(.v12),
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
            targets: [
                "GuanceSessionReplay",
                "GuanceSessionReplaySwiftUI",
            ]
        ),
        .library(
            name: "GuanceElectronWebView",
            targets: ["GuanceElectronWebView"]
        ),
    ],
    dependencies: [],
    targets: [
        // MARK: - GuanceSDK
        .target(
            name: "GuanceSDK",
            dependencies: [
                "_GuanceSDKObjC",
                "GuanceSDKSwiftUI",
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
                "GuanceSDKSwiftUI",
            ],
            path: "Sources",
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
            name: "GuanceSDKSwiftUI",
            path: "Sources/Agent/SwiftUI"
        ),
        .target(
            name: "_AgentConfig",
            dependencies: [
                "_FTBaseUtils_Base",
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
                "_FTBaseUtils_Base",
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
                "_FTBaseUtils_Base",
                "_FTBaseUtils_Thread",
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
                "_FTBaseUtils_Swizzle",
            ],
            path: "Sources/Core/URLSessionAutoInstrumentation",
            publicHeadersPath: "."
        ),
        .target(
            name: "_FTLogger",
            dependencies: [
                "_FTBaseUtils_Base",
                "_FTProtocol",
            ],
            path: "Sources/Core/Logger",
            publicHeadersPath: "."
        ),

        // MARK: - BaseUtils
        .target(
            name: "_FTBaseUtils_Base",
            dependencies: ["_FTBaseUtils_Thread"],
            path: "Sources/Core/BaseUtils/Base",
            publicHeadersPath: "."
        ),
        .target(
            name: "_FTBaseUtils_Swizzle",
            dependencies: ["_FTBaseUtils_Base"],
            path: "Sources/Core/BaseUtils/Swizzle",
            publicHeadersPath: "."
        ),
        .target(
            name: "_FTBaseUtils_Thread",
            path: "Sources/Core/BaseUtils/Thread"
        ),

        // MARK: - GuanceWidgetExtension
        .target(
            name: "_AgentExtension",
            dependencies: ["_FTBaseUtils_Base"],
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
                "_FTProtocol",
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
                "_FTProtocol",
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
            name: "GuanceSessionReplaySwiftUI",
            path: "Sources/SessionReplay/Recorder/SRWireframe/ViewTreeSnapshot/ViewsRecorder/SwiftUI"
        ),
        // MARK: - GuanceElectronWebView
        .target(
            name: "GuanceElectronWebView",
            dependencies: [
                "_GuanceSDKCore",
                "_FTProtocol",
                "GuanceSessionReplay",
            ],
            path: "Sources/ElectronWebView",
            exclude: ["GuanceElectronRUM"],
            publicHeadersPath: "Public",
            cSettings: [
                .headerSearchPath("."),
                .headerSearchPath("../SessionReplay"),
                .headerSearchPath("../SessionReplay/Processor/Builders"),
                .headerSearchPath("../SessionReplay/Recorder"),
                .headerSearchPath("../SessionReplay/Recorder/SRWireframe"),
                .headerSearchPath("../SessionReplay/Recorder/SRWireframe/ViewTreeSnapshot"),
                .headerSearchPath("../SessionReplay/Recorder/SRWireframe/ViewTreeSnapshot/ViewsRecorder"),
            ]
        ),
        .testTarget(
            name: "GuanceElectronWebViewTests",
            dependencies: [
                "GuanceElectronWebView",
                "_GuanceSDKCore",
                "_FTRUM",
                "_FTProtocol",
            ],
            path: "Tests/GuanceElectronWebViewTests"
        ),
    ]
)
