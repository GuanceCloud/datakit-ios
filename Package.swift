// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FTMobileSDK",
    platforms: [.iOS(.v11)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "FTMobileSDK",
            type: .static,
            targets: [
                      "FTMobileAgent",
                     ]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "FTMobileAgent",
            path: "FTMobileSDK",
            sources: ["BaseUtils","FTMobileAgent"],
            cSettings: [
                .headerSearchPath("BaseUtils/Base"),
                .headerSearchPath("BaseUtils/Thread"),
                .headerSearchPath("BaseUtils/Swizzle"),
                .headerSearchPath("BaseUtils/Network"),
                .headerSearchPath("BaseUtils/FTDataBase"),
                .headerSearchPath("BaseUtils/FTDataBase/fmdb"),
                .headerSearchPath("FTMobileAgent"),
                .headerSearchPath("FTMobileAgent/AutoTrack"),
                .headerSearchPath("FTMobileAgent/Exception"),
                .headerSearchPath("FTMobileAgent/Extension"),
                .headerSearchPath("FTMobileAgent/ExternalData"),
                .headerSearchPath("FTMobileAgent/FTRUM/Monitor"),
                .headerSearchPath("FTMobileAgent/FTRUM/RUMCore"),
                .headerSearchPath("FTMobileAgent/FTRUM/RUMCore/Model"),
                .headerSearchPath("FTMobileAgent/JSBridge"),
                .headerSearchPath("FTMobileAgent/LongTask"),
                .headerSearchPath("FTMobileAgent/Protocol"),
                .headerSearchPath("FTMobileAgent/URLSessionAutoInstrumentation"),
            ]
        ),
    ]
)
