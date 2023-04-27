// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FTMobileSDK",
    platforms: [.iOS(.v9),
                .macOS(.v10_13)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "FTMobileSDK",
            type: .static,
            targets: [
                      "FTMobileAgent",
                     ]),
        .library(
            name: "FTMobileExtension",
            type: .static,
            targets: [
                      "FTMobileExtension",
                     ]),
        .library(
            name: "FTMacOSSupport",
            type: .static,
            targets: [
                      "FTMacOSSupport",
                     ]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "FTMobileAgent",
            dependencies: [
                           "_FTBaseUtils-FTDataBase",
                           "_FTBaseUtils-Swizzle",
                           "_FTBaseUtils-Thread",
                           "_FTBaseUtils-Network",
                           "_FTRUM",
                           "_FTExtension",
                           "_FTExternalData",
                           "_FTException",
                           "_FTLongTask",
                           "_FTURLSessionAutoInstrumentation",
                           "_FTConfig",
                           "_FTWKWebView",
                           "_FTLogger"
                          ],
            path: "FTMobileSDK",
            sources: ["FTMobileAgent/FTGlobalRUMManager.h",
                      "FTMobileAgent/FTGlobalRUMManager.m",
                      "FTMobileAgent/FTMobileAgent.h",
                      "FTMobileAgent/FTMobileAgent+Private.h",
                      "FTMobileAgent/FTMobileAgent.m",
                      "FTMobileAgent/FTMobileAgent+Public.h",
                      "FTMobileAgent/FTMobileAgentVersion.h",
                      "FTMobileAgent/FTTraceManager.h",
                      "FTMobileAgent/FTTraceManager.m",
                      "FTMobileAgent/AutoTrack"
                     ],
            cSettings: [
                .headerSearchPath("FTMobileAgent/AutoTrack"),
                .headerSearchPath("FTMobileAgent/FTGlobalRUMManager.h"),
                .headerSearchPath("FTMobileAgent/FTGlobalRUMManager.m")

            ]
        ),
        .target(name: "_FTConfig",
                dependencies: ["_FTBaseUtils-Base"],
                path: "FTMobileSDK/FTMobileAgent",
                sources: ["FTMobileConfig.h",
                          "FTMobileConfig.m",
                          "FTMobileConfig+Private.h",],
                publicHeadersPath: ".",
                cSettings: [
                    
                ]),
        .target(name: "_FTExternalData",
                dependencies: ["_FTProtocol"],
                path: "FTMobileSDK/FTMobileAgent/ExternalData",
                publicHeadersPath: ".",
                cSettings: [
                    
                ]),
        .target(
            name: "_FTProtocol",
            dependencies: [],
            path: "FTMobileSDK/FTMobileAgent/Protocol",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("FTErrorDataProtocol.h"),
            ]
        ),
        .target(
            name: "_FTRUM",
            dependencies: ["_FTBaseUtils-Base",
                           "_FTBaseUtils-Thread",
                           "_FTProtocol"],
            path: "FTMobileSDK/FTMobileAgent/FTRUM",
            publicHeadersPath: "./.",
            cSettings: [
                .headerSearchPath("Monitor"),
            ]
        ),
        .target(name: "_FTURLSessionAutoInstrumentation",
                dependencies: ["_FTProtocol","_FTBaseUtils-Base","_FTBaseUtils-Swizzle"],
                path: "FTMobileSDK/FTMobileAgent/URLSessionAutoInstrumentation",
                publicHeadersPath: ".",
                cSettings: [

                ]),
        .target(name: "_FTLongTask",
                dependencies: ["_FTBaseUtils-Base"],
                path: "FTMobileSDK/FTMobileAgent/LongTask",
                publicHeadersPath: "."
               
               ),
        .target(name: "_FTLogger",
                dependencies: ["_FTBaseUtils-Base","_FTBaseUtils-Swizzle"],
                path: "FTMobileSDK/FTMobileAgent/Logger",
                publicHeadersPath: ".",
                cSettings: [
                    .headerSearchPath("FTLogHook.h")
                ]
               ),
        .target(name: "_FTWKWebView",
                dependencies: ["_FTBaseUtils-Base",
                               "_FTProtocol",
                               "_FTBaseUtils-Swizzle"
                              ],
                path: "FTMobileSDK/FTMobileAgent/FTWKWebView",
                publicHeadersPath: "Public",
                cSettings: [
                    .headerSearchPath("JSBridge")
                ]
               ),
        .target(name: "_FTException",
                dependencies: ["_FTBaseUtils-Base",
                               "_FTProtocol",
                              ],
                path: "FTMobileSDK/FTMobileAgent/Exception",
                publicHeadersPath: "."),
        
        // MARK: - BaseUtils
        .target(name: "_FTBaseUtils-Base",
                dependencies: [],
                path: "FTMobileSDK/BaseUtils/Base",
                publicHeadersPath: ".",
                cSettings: [
                    
                ]),
        .target(name: "_FTBaseUtils-FTDataBase",
                dependencies: ["_FTBaseUtils-Base"],
                path: "FTMobileSDK/BaseUtils/FTDataBase",
                publicHeadersPath: ".",
                cSettings: [
                    .headerSearchPath("fmdb"),
                ]),
        .target(name: "_FTBaseUtils-Network",
                dependencies: ["_FTBaseUtils-Base","_FTBaseUtils-FTDataBase","_FTBaseUtils-Thread"],
                path: "FTMobileSDK/BaseUtils/Network",
                publicHeadersPath: ".",
                cSettings: [
                    
                ]),
        .target(name: "_FTBaseUtils-Swizzle",
                dependencies: ["_FTBaseUtils-Base"],
                path: "FTMobileSDK/BaseUtils/Swizzle",
                publicHeadersPath: ".",
                cSettings: [
                    .headerSearchPath("Swizzle"),
                    .headerSearchPath("Swizzle/FTfishhook.c")
                ]),
        .target(name: "_FTBaseUtils-Thread",
                dependencies: [],
                path: "FTMobileSDK/BaseUtils/Thread",
                publicHeadersPath: ".",
                cSettings: [
                    
                ]),
        
        // MARK: - FTMobileExtension
        .target(name: "_FTExtension",
                dependencies: ["_FTBaseUtils-Base"],
                path: "FTMobileSDK/FTMobileAgent/Extension",
                publicHeadersPath: ".",
                cSettings: [
                    
                ]),
        .target(name: "FTMobileExtension",
                dependencies: ["_FTBaseUtils-Base",
                               "_FTExtension",
                               "_FTRUM",
                               "_FTURLSessionAutoInstrumentation",
                               "_FTException",
                               "_FTExternalData",
                               "_FTConfig"
                              ],
                path: "FTMobileSDK/FTMobileExtension",
                publicHeadersPath: ".",
                cSettings: [
                    
                ]),
        .target(name: "FTMacOSSupport",
                dependencies: [
                               "_FTBaseUtils-FTDataBase",
                               "_FTBaseUtils-Thread",
                               "_FTBaseUtils-Network",
                               "_FTRUM",
                               "_FTURLSessionAutoInstrumentation",
                               "_FTException",
                               "_FTWKWebView",
                               "_FTLongTask",
                               "_FTLogger"
                              ],
                path: "FTMobileSDK/FTMacOSSDK",
                publicHeadersPath: ".",
                cSettings: [
                    
                ]
               )
    ]
)
