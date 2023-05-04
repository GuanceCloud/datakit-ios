// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FTMobileSDK",
    platforms: [.iOS(.v10)],
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
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "FTMobileAgent",
            dependencies: [
                "_FTBaseUtils_Network",
                "_FTRUM",
                "_FTExtension",
                "_FTExternalData",
                "_FTException",
                "_FTLongTask",
                "_FTURLSessionAutoInstrumentation",
                "_FTJSBridge",
                "_FTLogger"
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
        
            .target(name: "FTMobileExtension",
                    dependencies: [
                        "_FTExtension",
                        "_FTRUM",
                        "_FTURLSessionAutoInstrumentation",
                        "_FTException",
                        "_FTExternalData",
                    ],
                    path: "FTMobileSDK/FTMobileExtension",
                    publicHeadersPath: ".",
                    cSettings: [
                        
                    ]),
        .target(name: "_FTExtension",
                dependencies: ["_FTBaseUtils_Base"],
                path: "FTMobileSDK/FTMobileAgent/Extension",
                publicHeadersPath: ".",
                cSettings: [
                    
                ]),
        
            .target(name: "_FTBaseUtils_Base",
                    dependencies: [],
                    path: "FTMobileSDK/BaseUtils/Base",
                    publicHeadersPath: ".",
                    cSettings: [
                        
                    ]),
        .target(name: "_FTBaseUtils_FTDataBase",
                dependencies: ["_FTBaseUtils_Base"],
                path: "FTMobileSDK/BaseUtils/FTDataBase",
                publicHeadersPath: ".",
                cSettings: [
                    .headerSearchPath("fmdb"),
                ]),
        .target(name: "_FTBaseUtils_Network",
                dependencies: ["_FTBaseUtils_Base","_FTBaseUtils_FTDataBase","_FTBaseUtils_Thread"],
                path: "FTMobileSDK/BaseUtils/Network",
                publicHeadersPath: ".",
                cSettings: [
                    
                ]),
        .target(name: "_FTBaseUtils_Swizzle",
                dependencies: ["_FTBaseUtils_Base"],
                path: "FTMobileSDK/BaseUtils/Swizzle",
                publicHeadersPath: ".",
                cSettings: [
                    .headerSearchPath("Swizzle"),
                    .headerSearchPath("Swizzle/FTfishhook.c")
                ]),
        .target(name: "_FTBaseUtils_Thread",
                dependencies: [],
                path: "FTMobileSDK/BaseUtils/Thread",
                publicHeadersPath: ".",
                cSettings: [
                    
                ]),
        
            .target(name: "_FTException",
                    dependencies: ["_FTBaseUtils_Base",
                                   "_FTProtocol",
                                  ],
                    path: "FTMobileSDK/FTMobileAgent/Exception",
                    publicHeadersPath: "."),
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
            ]
        ),
        .target(
            name: "_FTRUM",
            dependencies: ["_FTBaseUtils_Base",
                           "_FTBaseUtils_Thread",
                           "_FTProtocol"],
            path: "FTMobileSDK/FTMobileAgent/FTRUM",
            cSettings: [
                .headerSearchPath("Monitor"),
                .headerSearchPath("RUMCore"),
                .headerSearchPath("RUMCore/Model"),
                
            ]
        ),
        .target(name: "_FTURLSessionAutoInstrumentation",
                dependencies: ["_FTProtocol","_FTBaseUtils_Swizzle"],
                path: "FTMobileSDK/FTMobileAgent/URLSessionAutoInstrumentation",
                publicHeadersPath: ".",
                cSettings: [
                    
                ]),
        .target(name: "_FTLongTask",
                dependencies: ["_FTBaseUtils_Base"],
                path: "FTMobileSDK/FTMobileAgent/LongTask",
                publicHeadersPath: "."
                
               ),
        .target(name: "_FTJSBridge",
                dependencies: [
                    "_FTProtocol",
                    "_FTBaseUtils_Swizzle"
                ],
                path: "FTMobileSDK/FTMobileAgent/JSBridge",
                publicHeadersPath: ".",
                cSettings: [
                ]
               ),
        .target(name: "_FTLogger",
                dependencies: ["_FTBaseUtils_Base"],
                path: "FTMobileSDK/FTMobileAgent/Logger",
                publicHeadersPath: ".",
                cSettings: [
                    
                ]
               ),
        
        
        
    ]
)
