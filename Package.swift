// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FTMobileSDK",
    platforms: [.iOS(.v10),
                .macOS(.v10_13),
                .tvOS(.v12),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "FTMobileSDK",
            targets: [
                "FTMobileSDK",
            ]),
        .library(
            name: "FTMobileExtension",
            targets: [
                      "FTMobileExtension",
                     ]),
        .library(
            name: "FTSDKCore",
            targets: [
                      "FTSDKCore",
                     ]),
        .library(name: "FTBaseUtils_Base", targets: ["_FTBaseUtils_Base"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "FTMobileSDK",
            dependencies: [
                           "FTSDKCore",
                           "_FTExtension",
                           "_FTExternalData",
                           "_FTConfig",
                          ],
            path: "FTMobileSDK",
            sources: ["FTMobileAgent/Core",
                      "FTMobileAgent/AutoTrack"
                     ],
            cSettings: [
                .headerSearchPath("FTMobileAgent/Core"),
                .headerSearchPath("FTMobileAgent/AutoTrack")
            ]
        ),
        .target(name: "_FTConfig",
                dependencies: ["_FTBaseUtils_Base"],
                path: "FTMobileSDK/FTMobileAgent",
                sources: ["Config"],
                publicHeadersPath: "Config",
                cSettings: [
                    
                ]),
        .target(name: "_FTExternalData",
                dependencies: ["_FTProtocol",
                               "_FTBaseUtils_Base"],
                path: "FTMobileSDK/FTMobileAgent/ExternalData",
                publicHeadersPath: ".",
                cSettings: [
                    
                ]),
        .target(
            name: "_FTProtocol",
            dependencies: [],
            path: "FTMobileSDK/FTSDKCore/Protocol",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("FTErrorDataProtocol.h"),
            ]
        ),
        .target(
            name: "_FTRUM",
            dependencies: ["_FTBaseUtils_Base",
                           "_FTBaseUtils_Thread",
                           "_FTProtocol"],
            path: "FTMobileSDK/FTSDKCore/FTRUM",
            cSettings: [
                .headerSearchPath("Monitor"),
                .headerSearchPath("Crash"),
            ]
        ),
        .target(name: "_FTURLSessionAutoInstrumentation",
                dependencies: ["_FTProtocol","_FTBaseUtils_Swizzle"],
                path: "FTMobileSDK/FTSDKCore/URLSessionAutoInstrumentation",
                publicHeadersPath: ".",
                cSettings: [
                ]),
        .target(name: "_FTLogger",
                dependencies: ["_FTBaseUtils_Base",
                               "_FTProtocol"],
                path: "FTMobileSDK/FTSDKCore/Logger",
                publicHeadersPath: ".",
                cSettings: [
                   
                ]
               ),
        // MARK: - BaseUtils
        .target(name: "_FTBaseUtils_Base",
                dependencies: ["_FTBaseUtils_Thread"],
                path: "FTMobileSDK/FTSDKCore/BaseUtils/Base",
                publicHeadersPath: ".",
                cSettings: [
                    
                ]),
        .target(name: "_FTBaseUtils_Swizzle",
                dependencies: ["_FTBaseUtils_Base"],
                path: "FTMobileSDK/FTSDKCore/BaseUtils/Swizzle",
                publicHeadersPath: ".",
                cSettings: [
                   
                ]),
        .target(name: "_FTBaseUtils_Thread",
                path: "FTMobileSDK/FTSDKCore/BaseUtils/Thread",
                cSettings: [
                    
                ]),
        
        // MARK: - FTMobileExtension
        .target(name: "_FTExtension",
                dependencies: ["_FTBaseUtils_Base"],
                path: "FTMobileSDK/FTMobileAgent/Extension",
                publicHeadersPath: ".",
                cSettings: [
                    
                ]),
        .target(name: "FTMobileExtension",
                dependencies: [
                               "_FTExtension",
                               "_FTRUM",
                               "_FTURLSessionAutoInstrumentation",
                               "_FTExternalData",
                               "_FTLogger",
                               "_FTConfig"
                              ],
                path: "FTMobileSDK",
                sources: ["FTMobileExtension"],
                resources: [
                    .copy("Resources/PrivacyInfo.xcprivacy")],
                publicHeadersPath: "FTMobileExtension/include",
                cSettings: [
                    
                ]),
        .target(name: "FTSDKCore",
                dependencies: [
                               "_FTRUM",
                               "_FTURLSessionAutoInstrumentation",
                               "_FTLogger"
                              ],
                path: "FTMobileSDK",
                sources: ["FTSDKCore/FTWKWebView","FTSDKCore/DataManager"],
                resources: [
                    .copy("Resources/PrivacyInfo.xcprivacy")],
                publicHeadersPath: "FTSDKCore/include",
                cSettings: [
                    .headerSearchPath("FTSDKCore/DataManager/Upload"),
                    .headerSearchPath("FTSDKCore/DataManager/Storage"),
                    .headerSearchPath("FTSDKCore/DataManager/Storage/fmdb"),
                    .headerSearchPath("FTSDKCore/FTWKWebView/JSBridge"),

                ]
               )
    ]
)
