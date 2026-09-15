import Foundation
import GuanceElectronWebView
import XCTest
@testable import OrbitDeskNativeHost

final class ElectronProcessControllerTests: XCTestCase {
    private var directory: URL!
    private var pidFile: URL!
    private var controller: ElectronProcessController!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        pidFile = directory.appendingPathComponent("electron-pids.json")
        controller = ElectronProcessController(pidFileURL: pidFile)
    }

    override func tearDownWithError() throws {
        controller.terminateAll()
        try FileManager.default.removeItem(at: directory)
    }

    func testConcurrentChildrenKeepOwnEnvironmentAndSurvivePeerExitAndReplacement() throws {
        let parentEnvironment = ProcessInfo.processInfo.environment
        let (processA, inputA, outputA) = makeProcess()
        let (processB, inputB, outputB) = makeProcess()
        let first = try controller.launch(processA)
        let second = try controller.launch(processB)
        let expectedA = try expectedOutput(first)
        let expectedB = try expectedOutput(second)
        XCTAssertEqual(first.instanceID, 1)
        XCTAssertEqual(second.instanceID, 2)
        XCTAssertEqual(try recordedPIDs(), [processA.processIdentifier, processB.processIdentifier].sorted())
        XCTAssertNotEqual(first.bridgeServer.socketPath, second.bridgeServer.socketPath)
        XCTAssertNotEqual(first.bridgeServer.authenticationToken, second.bridgeServer.authenticationToken)
        XCTAssertTrue(processA.isRunning)
        XCTAssertTrue(processB.isRunning)

        let firstExited = expectation(description: "Only first child exits")
        controller.onExit = { child in
            XCTAssertEqual(child.instanceID, 1)
            XCTAssertEqual(child.process.terminationStatus, 0)
            firstExited.fulfill()
        }
        try inputA.fileHandleForWriting.close()
        wait(for: [firstExited], timeout: 5)
        XCTAssertEqual(readOutput(outputA), expectedA)
        XCTAssertFalse(first.bridgeServer.isRunning)
        XCTAssertEqual(Set(controller.children.keys), [2])
        XCTAssertTrue(processB.isRunning)
        XCTAssertTrue(second.bridgeServer.isRunning)
        XCTAssertEqual(try recordedPIDs(), [processB.processIdentifier])

        let (processC, inputC, outputC) = makeProcess()
        let replacement = try controller.launch(processC)
        let expectedC = try expectedOutput(replacement)
        XCTAssertEqual(replacement.instanceID, 3)
        XCTAssertEqual(Set(controller.children.keys), [2, 3])
        XCTAssertEqual(try recordedPIDs(), [processB.processIdentifier, processC.processIdentifier].sorted())

        let remainingExited = expectation(description: "Remaining children exit independently")
        remainingExited.expectedFulfillmentCount = 2
        controller.onExit = { child in
            XCTAssertTrue([2, 3].contains(child.instanceID))
            XCTAssertEqual(child.process.terminationStatus, 0)
            remainingExited.fulfill()
        }
        try inputB.fileHandleForWriting.close()
        try inputC.fileHandleForWriting.close()
        wait(for: [remainingExited], timeout: 5)
        XCTAssertEqual(readOutput(outputB), expectedB)
        XCTAssertEqual(readOutput(outputC), expectedC)
        XCTAssertTrue(controller.children.isEmpty)
        XCTAssertEqual(try recordedPIDs(), [])
        XCTAssertEqual(ProcessInfo.processInfo.environment, parentEnvironment)
    }

    func testFailedLaunchRemovesItsBridgeAndDoesNotReplaceExistingChild() throws {
        let (runningProcess, input, _) = makeProcess()
        let running = try controller.launch(runningProcess)
        defer { try? input.fileHandleForWriting.close() }
        let failed = Process()
        failed.executableURL = directory.appendingPathComponent("missing-electron")
        XCTAssertThrowsError(try controller.launch(failed))
        let failedSocket = try XCTUnwrap(failed.environment?[FTElectronBridgeSocketPathEnvironmentKey])
        XCTAssertFalse(FileManager.default.fileExists(atPath: failedSocket))
        XCTAssertEqual(Set(controller.children.keys), [1])
        XCTAssertTrue(running.process.isRunning)
        XCTAssertTrue(running.bridgeServer.isRunning)
        XCTAssertEqual(try recordedPIDs(), [runningProcess.processIdentifier])
    }

    func testTerminateAllCleansEveryProcessBridgeAndPIDFile() throws {
        let (processA, inputA, _) = makeProcess()
        let (processB, inputB, _) = makeProcess()
        defer {
            try? inputA.fileHandleForWriting.close()
            try? inputB.fileHandleForWriting.close()
        }
        let first = try controller.launch(processA)
        let second = try controller.launch(processB)
        let paths = [try XCTUnwrap(first.bridgeServer.socketPath), try XCTUnwrap(second.bridgeServer.socketPath)]
        controller.onExit = { _ in XCTFail("Shutdown must ignore queued exit callbacks") }
        controller.terminateAll()
        XCTAssertFalse(processA.isRunning)
        XCTAssertFalse(processB.isRunning)
        XCTAssertFalse(first.bridgeServer.isRunning)
        XCTAssertFalse(second.bridgeServer.isRunning)
        XCTAssertTrue(controller.children.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pidFile.path))
        for path in paths { XCTAssertFalse(FileManager.default.fileExists(atPath: path)) }
        let drained = expectation(description: "Drain queued exit callbacks")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 5)
    }

    private func makeProcess() -> (Process, Pipe, Pipe) {
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            #"printf '%s\n' "$GUANCE_ELECTRON_SOCKET_PATH" "$GUANCE_ELECTRON_AUTH_TOKEN" "$GUANCE_ELECTRON_PROTOCOL_VERSION" "$ORBITDESK_ELECTRON_INSTANCE_ID" "$EXAMPLE_CUSTOM_VALUE"; read -r line; exit 0"#,
        ]
        process.environment = ["EXAMPLE_CUSTOM_VALUE": "preserved"]
        process.standardInput = input
        process.standardOutput = output
        return (process, input, output)
    }

    private func expectedOutput(_ child: ElectronChildSession) throws -> [String] {
        [try XCTUnwrap(child.bridgeServer.socketPath),
         try XCTUnwrap(child.bridgeServer.authenticationToken),
         "1", String(child.instanceID), "preserved"]
    }

    private func readOutput(_ pipe: Pipe) -> [String] {
        String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .split(separator: "\n").map(String.init)
    }

    private func recordedPIDs() throws -> [Int32] {
        try JSONDecoder().decode([Int32].self, from: Data(contentsOf: pidFile))
    }
}
