// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "OrbitDeskNativeHost",
    platforms: [.macOS(.v13)],
    products: [
        .executable(
            name: "OrbitDeskNativeHost",
            targets: ["OrbitDeskNativeHost"]
        ),
    ],
    dependencies: [
        .package(
            name: "datakit-ios",
            path: "../../../../.."
        ),
    ],
    targets: [
        .executableTarget(
            name: "OrbitDeskNativeHost",
            dependencies: [
                .product(name: "GuanceSDK", package: "datakit-ios"),
                .product(name: "GuanceSessionReplay", package: "datakit-ios"),
                .product(name: "GuanceElectronWebView", package: "datakit-ios"),
            ],
            path: "Sources/OrbitDeskNativeHost",
            linkerSettings: [
                .linkedFramework("AppKit"),
            ]
        ),
        .testTarget(
            name: "OrbitDeskNativeHostTests",
            dependencies: ["OrbitDeskNativeHost"],
            path: "Tests/OrbitDeskNativeHostTests"
        ),
    ]
)
