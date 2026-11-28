import Darwin
import Foundation
import XCTest
@testable import GuanceElectronWebView

final class FTElectronBridgeServerTests: XCTestCase {
    private let handler = FTElectronWebViewHandler.sharedInstance()

    override func setUp() {
        super.setUp()
        handler.removeAllRegistrations()
    }

    override func tearDown() {
        handler.removeAllRegistrations()
        super.tearDown()
    }

    func testServerGeneratesLaunchEnvironmentAndRemovesSocketOnStop() throws {
        let server = FTElectronBridgeServer()
        try server.start()
        XCTAssertTrue(server.isRunning)
        guard let socketPath = server.socketPath,
              let token = server.authenticationToken else {
            return XCTFail("Server did not generate launch credentials")
        }

        let environment = server.environmentByAdding(
            toEnvironment: ["EXISTING": "1"]
        )
        XCTAssertEqual(environment["EXISTING"], "1")
        XCTAssertEqual(
            environment[FTElectronBridgeSocketPathEnvironmentKey],
            socketPath
        )
        XCTAssertEqual(
            environment[FTElectronBridgeAuthenticationTokenEnvironmentKey],
            token
        )
        XCTAssertEqual(
            environment[FTElectronBridgeProtocolVersionEnvironmentKey],
            "1"
        )

        let attributes = try FileManager.default.attributesOfItem(
            atPath: socketPath
        )
        let permissions = attributes[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o600)

        server.stop()
        XCTAssertFalse(server.isRunning)
        XCTAssertFalse(FileManager.default.fileExists(atPath: socketPath))
    }

    func testProcessConfigurationStartsServerAndPreservesExplicitEnvironment() throws {
        let server = FTElectronBridgeServer()
        defer { server.stop() }
        let process = Process()
        process.environment = [
            "EXISTING": "keep",
            FTElectronBridgeSocketPathEnvironmentKey: "stale-path",
            FTElectronBridgeAuthenticationTokenEnvironmentKey: "stale-token",
        ]
        try server.configureElectronProcess(process)
        XCTAssertTrue(server.isRunning)
        XCTAssertFalse(process.isRunning)
        XCTAssertEqual(process.environment?["EXISTING"], "keep")
        XCTAssertEqual(process.environment?[FTElectronBridgeSocketPathEnvironmentKey],
                       server.socketPath)
        XCTAssertEqual(process.environment?[FTElectronBridgeAuthenticationTokenEnvironmentKey],
                       server.authenticationToken)
        XCTAssertEqual(process.environment?[FTElectronBridgeProtocolVersionEnvironmentKey], "1")
        let firstEnvironment = process.environment
        try server.configureElectronProcess(process)
        XCTAssertEqual(process.environment, firstEnvironment)
    }

    func testProcessesReadTheirOwnBridgeEnvironmentWithoutChangingParent() throws {
        let parentEnvironment = ProcessInfo.processInfo.environment
        let first = FTElectronBridgeServer()
        let second = FTElectronBridgeServer()
        defer { first.stop(); second.stop() }
        let keys = [
            FTElectronBridgeSocketPathEnvironmentKey,
            FTElectronBridgeAuthenticationTokenEnvironmentKey,
            FTElectronBridgeProtocolVersionEnvironmentKey,
        ]
        let processes = [Process(), Process()]
        let outputs = [Pipe(), Pipe()]
        for (index, server) in [first, second].enumerated() {
            let process = processes[index]
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = [
                "-c",
                #"printf '%s\n' "$GUANCE_ELECTRON_SOCKET_PATH" "$GUANCE_ELECTRON_AUTH_TOKEN" "$GUANCE_ELECTRON_PROTOCOL_VERSION""#,
            ]
            process.standardOutput = outputs[index]
            try server.configureElectronProcess(process)
            for (key, value) in parentEnvironment where !keys.contains(key) {
                XCTAssertEqual(process.environment?[key], value, "Inherited key: \(key)")
            }
            try process.run()
        }
        for (index, server) in [first, second].enumerated() {
            let data = outputs[index].fileHandleForReading.readDataToEndOfFile()
            processes[index].waitUntilExit()
            XCTAssertEqual(processes[index].terminationStatus, 0)
            let values = String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init)
            XCTAssertEqual(values, [try XCTUnwrap(server.socketPath),
                                    try XCTUnwrap(server.authenticationToken), "1"])
            XCTAssertThrowsError(try server.configureElectronProcess(processes[index]))
        }
        XCTAssertNotEqual(first.socketPath, second.socketPath)
        XCTAssertNotEqual(first.authenticationToken, second.authenticationToken)
        XCTAssertEqual(ProcessInfo.processInfo.environment, parentEnvironment)
    }

    func testAuthenticatedProtocolOwnsAndCleansStandaloneRegistration() throws {
        let server = FTElectronBridgeServer()
        try server.start()
        XCTAssertTrue(server.isRunning)
        defer { server.stop() }
        guard let socketPath = server.socketPath,
              let token = server.authenticationToken else {
            return XCTFail("Server did not generate launch credentials")
        }

        let descriptor = try connect(to: socketPath)
        defer { Darwin.close(descriptor) }
        let connectionID = UUID().uuidString
        try writeJSON([
            "protocolVersion": 1,
            "type": "hello",
            "connectionID": connectionID,
            "authenticationToken": token,
        ], to: descriptor)
        let ready = try readJSON(from: descriptor)
        XCTAssertEqual(ready["type"] as? String, "ready")
        XCTAssertEqual(ready["connectionID"] as? String, connectionID)

        try writeJSON([
            "protocolVersion": 1,
            "type": "register",
            "connectionID": connectionID,
            "sequence": 1,
            "requestID": "1",
            "webContentsID": 401,
            "visible": true,
        ], to: descriptor)
        let registration = try readJSON(from: descriptor)
        XCTAssertEqual(registration["type"] as? String, "ack")
        XCTAssertEqual(registration["ok"] as? Bool, true)
        XCTAssertNotNil(registration["slotID"] as? NSNumber)
        // External registrations never occupy the managed singleton's table.
        XCTAssertNil(handler.slotID(forWebContentsID: 401))

        try writeJSON([
            "protocolVersion": 1,
            "type": "event",
            "connectionID": connectionID,
            "sequence": 2,
            "requestID": "2",
            "webContentsID": 401,
            "payload": #"[{"handlerName":"sendEvent","data":{"name":"rum"}}]"#,
        ], to: descriptor)
        let event = try readJSON(from: descriptor)
        XCTAssertEqual(event["ok"] as? Bool, true)

        try writeJSON([
            "protocolVersion": 1,
            "type": "close",
            "connectionID": connectionID,
            "sequence": 3,
            "requestID": "3",
        ], to: descriptor)
        let close = try readJSON(from: descriptor)
        XCTAssertEqual(close["ok"] as? Bool, true)
        XCTAssertNil(handler.slotID(forWebContentsID: 401))
    }

    func testServerRejectsWrongAuthenticationToken() throws {
        let server = FTElectronBridgeServer()
        try server.start()
        XCTAssertTrue(server.isRunning)
        defer { server.stop() }
        guard let socketPath = server.socketPath else {
            return XCTFail("Server did not generate a socket path")
        }

        let descriptor = try connect(to: socketPath)
        defer { Darwin.close(descriptor) }
        try writeJSON([
            "protocolVersion": 1,
            "type": "hello",
            "connectionID": UUID().uuidString,
            "authenticationToken": "wrong-token",
        ], to: descriptor)
        XCTAssertThrowsError(try readJSON(from: descriptor))
        XCTAssertEqual(handler.registeredWebContentsCount(), 0)
    }

    func testServerRejectsUnknownOperationAndClosesConnection() throws {
        let server = FTElectronBridgeServer()
        try server.start()
        defer { server.stop() }
        guard let socketPath = server.socketPath,
              let token = server.authenticationToken else {
            return XCTFail("Server did not generate launch credentials")
        }

        let descriptor = try connect(to: socketPath)
        defer { Darwin.close(descriptor) }
        let connectionID = UUID().uuidString
        try writeJSON([
            "protocolVersion": 1,
            "type": "hello",
            "connectionID": connectionID,
            "authenticationToken": token,
        ], to: descriptor)
        _ = try readJSON(from: descriptor)

        try writeJSON([
            "protocolVersion": 1,
            "type": "unsupported",
            "connectionID": connectionID,
            "sequence": 1,
            "requestID": "1",
        ], to: descriptor)
        let rejection = try readJSON(from: descriptor)
        XCTAssertEqual(rejection["ok"] as? Bool, false)
        XCTAssertThrowsError(try readJSON(from: descriptor))
        XCTAssertEqual(handler.registeredWebContentsCount(), 0)
    }

    func testServerRejectsNonMonotonicSequence() throws {
        let server = FTElectronBridgeServer()
        try server.start()
        defer { server.stop() }
        guard let socketPath = server.socketPath,
              let token = server.authenticationToken else {
            return XCTFail("Server did not generate launch credentials")
        }

        let descriptor = try connect(to: socketPath)
        defer { Darwin.close(descriptor) }
        let connectionID = UUID().uuidString
        try writeJSON([
            "protocolVersion": 1,
            "type": "hello",
            "connectionID": connectionID,
            "authenticationToken": token,
        ], to: descriptor)
        _ = try readJSON(from: descriptor)

        try writeJSON([
            "protocolVersion": 1,
            "type": "ping",
            "connectionID": connectionID,
            "sequence": 2,
            "requestID": "2",
        ], to: descriptor)
        XCTAssertThrowsError(try readJSON(from: descriptor))
        XCTAssertEqual(handler.registeredWebContentsCount(), 0)
    }

    func testConcurrentServersIsolateIdenticalWebContentsIDsAndDisconnects() throws {
        let first = FTElectronBridgeServer()
        let second = FTElectronBridgeServer()
        try first.start()
        try second.start()
        defer { first.stop(); second.stop() }
        XCTAssertNotEqual(first.socketPath, second.socketPath)
        XCTAssertNotEqual(first.authenticationToken, second.authenticationToken)
        let a = try authenticate(first)
        let b = try authenticate(second)
        defer { Darwin.close(a); Darwin.close(b) }

        let slotA = try request(a, type: "register", sequence: 1)["slotID"] as? NSNumber
        let slotB = try request(b, type: "register", sequence: 1)["slotID"] as? NSNumber
        XCTAssertNotNil(slotA)
        XCTAssertNotNil(slotB)
        XCTAssertNotEqual(slotA, slotB)
        XCTAssertEqual(handler.registeredWebContentsCount(), 0)

        // Hiding A must not suppress B's events with the same local ID.
        XCTAssertEqual(try request(a, type: "update", sequence: 2,
                                  extra: ["visible": false])["ok"] as? Bool, true)
        let payload = #"[{"handlerName":"sendEvent","data":{"name":"rum"}}]"#
        XCTAssertEqual(try request(a, type: "event", sequence: 3,
                                  extra: ["payload": payload])["ok"] as? Bool, false)
        XCTAssertEqual(try request(b, type: "event", sequence: 2,
                                  extra: ["payload": payload])["ok"] as? Bool, true)
        XCTAssertEqual(try request(a, type: "close", sequence: 4)["ok"] as? Bool, true)

        // A reconnect owns a new registration; stopping it leaves B usable.
        let reconnected = try authenticate(first)
        defer { Darwin.close(reconnected) }
        let newSlot = try request(reconnected, type: "register", sequence: 1)["slotID"] as? NSNumber
        XCTAssertNotNil(newSlot)
        XCTAssertNotEqual(newSlot, slotA)
        XCTAssertNotEqual(newSlot, slotB)
        first.stop()
        XCTAssertEqual(try request(b, type: "event", sequence: 3,
                                  extra: ["payload": payload])["ok"] as? Bool, true)
        XCTAssertEqual(try request(b, type: "unregister", sequence: 4)["ok"] as? Bool, true)
        XCTAssertEqual(try request(b, type: "close", sequence: 5)["ok"] as? Bool, true)
    }

    private func authenticate(_ server: FTElectronBridgeServer) throws -> Int32 {
        let descriptor = try connect(to: XCTUnwrap(server.socketPath))
        do {
            try writeJSON([
                "protocolVersion": 1, "type": "hello",
                "connectionID": "same-client-local-id",
                "authenticationToken": try XCTUnwrap(server.authenticationToken),
            ], to: descriptor)
            XCTAssertEqual(try readJSON(from: descriptor)["type"] as? String, "ready")
            return descriptor
        } catch {
            Darwin.close(descriptor)
            throw error
        }
    }

    private func request(
        _ descriptor: Int32, type: String, sequence: Int,
        extra: [String: Any] = [:]
    ) throws -> [String: Any] {
        var message: [String: Any] = [
            "protocolVersion": 1, "type": type,
            "connectionID": "same-client-local-id",
            "sequence": sequence, "requestID": String(sequence),
            "webContentsID": 1,
        ]
        message.merge(extra) { _, value in value }
        try writeJSON(message, to: descriptor)
        return try readJSON(from: descriptor)
    }

    private func connect(to socketPath: String) throws -> Int32 {
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw SocketError.create }

        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(
            descriptor,
            SOL_SOCKET,
            SO_RCVTIMEO,
            &timeout,
            socklen_t(MemoryLayout<timeval>.size)
        )
        var address = sockaddr_un()
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        address.sun_family = sa_family_t(AF_UNIX)
        let path = Array(socketPath.utf8CString)
        guard path.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            Darwin.close(descriptor)
            throw SocketError.pathTooLong
        }
        withUnsafeMutablePointer(to: &address.sun_path) { destination in
            let bytes = UnsafeMutableRawPointer(destination)
                .assumingMemoryBound(to: CChar.self)
            for (index, value) in path.enumerated() {
                bytes[index] = value
            }
        }
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(
                    descriptor,
                    $0,
                    socklen_t(MemoryLayout<sockaddr_un>.size)
                )
            }
        }
        guard result == 0 else {
            Darwin.close(descriptor)
            throw SocketError.connect(errno)
        }
        return descriptor
    }

    private func writeJSON(
        _ object: [String: Any],
        to descriptor: Int32
    ) throws {
        var data = try JSONSerialization.data(withJSONObject: object)
        data.append(0x0a)
        let written = data.withUnsafeBytes { bytes in
            Darwin.write(descriptor, bytes.baseAddress, bytes.count)
        }
        guard written == data.count else { throw SocketError.write }
    }

    private func readJSON(from descriptor: Int32) throws -> [String: Any] {
        var data = Data()
        var byte: UInt8 = 0
        while true {
            let count = Darwin.read(descriptor, &byte, 1)
            guard count > 0 else { throw SocketError.read }
            if byte == 0x0a { break }
            data.append(byte)
            if data.count > 2 * 1024 * 1024 { throw SocketError.read }
        }
        guard let object = try JSONSerialization.jsonObject(with: data)
            as? [String: Any] else {
            throw SocketError.read
        }
        return object
    }
}

private enum SocketError: Error {
    case create
    case pathTooLong
    case connect(Int32)
    case write
    case read
}
