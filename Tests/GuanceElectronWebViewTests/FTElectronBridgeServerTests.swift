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
        XCTAssertNotNil(handler.slotID(forWebContentsID: 401))

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
