import Foundation
import XCTest
@testable import OrbitDeskNativeHost

final class LaunchConfigurationTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testDirectNativeRunDiscoversElectronProjectAndDotEnv() throws {
        try createProjectFixture()
        let sourceFile = temporaryDirectory
            .appendingPathComponent("macos/Sources/Host/main.swift")
        let environment = NativeHostEnvironment(
            processEnvironment: [:],
            sourceFilePath: sourceFile.path,
            currentDirectoryURL: temporaryDirectory.appendingPathComponent("macos"),
            bundleResourceURL: nil
        )

        let configuration = try ElectronLaunchConfiguration.resolve(
            environment: environment
        )

        XCTAssertEqual(configuration.projectRootURL, temporaryDirectory)
        XCTAssertEqual(environment.value("GUANCE_NATIVE_APP_ID"), "native-test-app")
        XCTAssertEqual(
            configuration.executableURL.path,
            temporaryDirectory.appendingPathComponent(
                "native-build/OrbitDeskElectronAccessory.app/Contents/MacOS/Electron"
            ).path
        )
    }

    func testProcessEnvironmentOverridesDotEnv() throws {
        try createProjectFixture()
        let environment = NativeHostEnvironment(
            processEnvironment: [
                "ORBITDESK_ELECTRON_PROJECT_ROOT": temporaryDirectory.path,
                "GUANCE_NATIVE_APP_ID": "process-app",
            ],
            sourceFilePath: "/missing/source.swift",
            currentDirectoryURL: URL(fileURLWithPath: "/"),
            bundleResourceURL: nil
        )

        XCTAssertEqual(environment.value("GUANCE_NATIVE_APP_ID"), "process-app")
        XCTAssertNoThrow(try ElectronLaunchConfiguration.resolve(environment: environment))
    }

    private func createProjectFixture() throws {
        let fileManager = FileManager.default
        let paths = [
            "electron",
            "dist",
            "macos/Sources/Host",
            "native-build/OrbitDeskElectronAccessory.app/Contents/MacOS",
        ]
        for path in paths {
            try fileManager.createDirectory(
                at: temporaryDirectory.appendingPathComponent(path),
                withIntermediateDirectories: true
            )
        }
        try "{}".write(
            to: temporaryDirectory.appendingPathComponent("package.json"),
            atomically: true,
            encoding: .utf8
        )
        try "".write(
            to: temporaryDirectory.appendingPathComponent("electron/main.cjs"),
            atomically: true,
            encoding: .utf8
        )
        try "GUANCE_NATIVE_APP_ID=native-test-app\n".write(
            to: temporaryDirectory.appendingPathComponent(".env.local"),
            atomically: true,
            encoding: .utf8
        )
        try "".write(
            to: temporaryDirectory.appendingPathComponent("dist/index.html"),
            atomically: true,
            encoding: .utf8
        )
        let executable = temporaryDirectory.appendingPathComponent(
            "native-build/OrbitDeskElectronAccessory.app/Contents/MacOS/Electron"
        )
        try "#!/bin/sh\n".write(to: executable, atomically: true, encoding: .utf8)
        try fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )
    }
}
