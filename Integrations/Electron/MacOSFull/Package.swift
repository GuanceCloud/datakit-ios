// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Guanceelectron",
    platforms: [
        .macOS(.v10_14),
    ],
    products: [
        .library(
            name: "GuanceElectronNative",
            type: .dynamic,
            targets: ["GuanceElectronBridge"]
        ),
    ],
    dependencies: [
        .package(
            name: "GuanceSDKRoot",
            path: "../../.."
        ),
    ],
    targets: [
        .target(
            name: "GuanceElectronBridge",
            dependencies: [
                .product(
                    name: "GuanceElectronWebView",
                    package: "GuanceSDKRoot"
                ),
            ],
            path: "NativeBridge",
            publicHeadersPath: "Public",
            linkerSettings: [
                .linkedFramework("AppKit"),
            ]
        ),
    ]
)
