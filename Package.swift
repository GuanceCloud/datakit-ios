// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FTMobileSDK",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_14),
        .tvOS(.v12),
    ],
    products: [
        .library(
            name: "FTMobileSDK",
            targets: [
                "FTMobileSDK",
                "FTMobileSDKSwiftUI",
            ]
        ),
        .library(
            name: "FTMobileExtension",
            targets: ["FTMobileExtension"]
        ),
        .library(
            name: "FTSDKCore",
            targets: ["FTSDKCore"]
        ),
        .library(
            name: "FTSessionReplay",
            targets: [
                "FTSessionReplay",
                "FTSessionReplaySwiftUI",
            ]
        ),
    ],
    dependencies: [],
    targets: [
        // MARK: - FTMobileSDK
        .target(
            name: "FTMobileSDK",
            dependencies: [
                "_FTMobileSDKObjC",
                "FTMobileSDKSwiftUI",
            ],
            path: "FTMobileSDK/SwiftPM",
            sources: ["FTMobileSDK.swift"]
        ),
        .target(
            name: "_FTMobileSDKObjC",
            dependencies: [
                "FTSDKCore",
                "_FTExtension",
                "_FTExternalData",
                "_FTConfig",
                "FTMobileSDKSwiftUI",
            ],
            path: "FTMobileSDK",
            sources: [
                "FTMobileAgent/Core",
                "FTMobileAgent/AutoTrack",
            ],
            cSettings: [
                .headerSearchPath("FTMobileAgent/Core"),
                .headerSearchPath("FTMobileAgent/AutoTrack"),
                .headerSearchPath("FTSDKCore/DataFilter")
            ]
        ),
        .target(
            name: "FTMobileSDKSwiftUI",
            path: "FTMobileSDK/FTMobileAgent/SwiftUI"
        ),
        .target(
            name: "_FTConfig",
            dependencies: [
                "_FTBaseUtils_Base",
                "_FTRUM",
                "_FTProtocol",
            ],
            path: "FTMobileSDK/FTMobileAgent",
            sources: ["Config"],
            publicHeadersPath: "Config"
        ),
        .target(
            name: "_FTExternalData",
            dependencies: [
                "_FTProtocol",
                "_FTBaseUtils_Base",
            ],
            path: "FTMobileSDK/FTMobileAgent/ExternalData",
            publicHeadersPath: "."
        ),
        .target(
            name: "_FTProtocol",
            dependencies: [],
            path: "FTMobileSDK/FTSDKCore/Protocol",
            publicHeadersPath: "."
        ),
        .target(
            name: "_FTRUM",
            dependencies: [
                "_FTBaseUtils_Base",
                "_FTBaseUtils_Thread",
                "_FTProtocol",
            ],
            path: "FTMobileSDK/FTSDKCore/FTRUM",
            cSettings: [
                .headerSearchPath("Monitor"),
                .headerSearchPath("FTCrash"),
                .headerSearchPath("FTCrash/RecordingCore"),
                .headerSearchPath("FTCrash/Recording"),
                .headerSearchPath("FTCrash/Recording/Monitors"),
                .headerSearchPath("RUMCore"),
            ]
        ),
        .target(
            name: "_FTURLSessionAutoInstrumentation",
            dependencies: [
                "_FTProtocol",
                "_FTBaseUtils_Swizzle",
            ],
            path: "FTMobileSDK/FTSDKCore/URLSessionAutoInstrumentation",
            publicHeadersPath: "."
        ),
        .target(
            name: "_FTLogger",
            dependencies: [
                "_FTBaseUtils_Base",
                "_FTProtocol",
            ],
            path: "FTMobileSDK/FTSDKCore/Logger",
            publicHeadersPath: "."
        ),

        // MARK: - BaseUtils
        .target(
            name: "_FTBaseUtils_Base",
            dependencies: ["_FTBaseUtils_Thread"],
            path: "FTMobileSDK/FTSDKCore/BaseUtils/Base",
            publicHeadersPath: "."
        ),
        .target(
            name: "_FTBaseUtils_Swizzle",
            dependencies: ["_FTBaseUtils_Base"],
            path: "FTMobileSDK/FTSDKCore/BaseUtils/Swizzle",
            publicHeadersPath: "."
        ),
        .target(
            name: "_FTBaseUtils_Thread",
            path: "FTMobileSDK/FTSDKCore/BaseUtils/Thread"
        ),

        // MARK: - FTMobileExtension
        .target(
            name: "_FTExtension",
            dependencies: ["_FTBaseUtils_Base"],
            path: "FTMobileSDK/FTMobileAgent/Extension",
            publicHeadersPath: "."
        ),
        .target(
            name: "FTMobileExtension",
            dependencies: [
                "_FTExtension",
                "_FTRUM",
                "_FTURLSessionAutoInstrumentation",
                "_FTExternalData",
                "_FTLogger",
                "_FTConfig",
            ],
            path: "FTMobileSDK/FTMobileExtension",
            resources: [
                .copy("../Resources/PrivacyInfo.xcprivacy"),
            ],
            publicHeadersPath: "."
        ),

        // MARK: - FTSDKCore
        .target(
            name: "FTSDKCore",
            dependencies: [
                "_FTRUM",
                "_FTURLSessionAutoInstrumentation",
                "_FTLogger",
            ],
            path: "FTMobileSDK",
            sources: [
                "FTSDKCore/FTWKWebView",
                "FTSDKCore/DataManager",
                "FTSDKCore/RemoteConfig",
                "FTSDKCore/DataFilter",
            ],
            resources: [
                .copy("Resources/PrivacyInfo.xcprivacy"),
            ],
            publicHeadersPath: "FTSDKCore/include",
            cSettings: [
                .headerSearchPath("FTSDKCore/DataManager/Upload"),
                .headerSearchPath("FTSDKCore/DataManager/Storage"),
                .headerSearchPath("FTSDKCore/DataManager/Storage/fmdb"),
                .headerSearchPath("FTSDKCore/FTWKWebView/JSBridge"),
                .headerSearchPath("FTSDKCore/DataFilter"),
            ]
        ),

        // MARK: - FTSessionReplay
        .target(
            name: "FTSessionReplay",
            dependencies: ["FTSDKCore"],
            path: "FTMobileSDK/FTSessionReplay",
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
            name: "FTSessionReplaySwiftUI",
            path: "FTMobileSDK/FTSessionReplay/Recorder/SRWireframe/ViewTreeSnapshot/ViewsRecorder/SwiftUI",
            sources: ["FTSwiftUIReflection.swift"]
        ),
    ]
)
