//
//  GuanceElectronNativeTests.swift
//  GuanceElectronNativeTests
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//

#if os(macOS)
import XCTest
import GuanceElectronNative

final class GuanceElectronNativeTests: XCTestCase {
    func testCBridgeReturnsFramedErrorForUnsupportedMethod() throws {
        let result = try XCTUnwrap(guance_electron_invoke("unsupported.method", "{}"))
        defer { guance_electron_free_string(result) }

        let response = String(cString: result)
        XCTAssertTrue(response.hasPrefix("1"))
        XCTAssertTrue(response.contains("Unsupported Native method"))
    }

    func testCBridgeExposesWebViewConfiguration() throws {
        let requiredCapacity = guance_electron_bridge_configuration(nil, 0)
        XCTAssertGreaterThan(requiredCapacity, 1)

        var buffer = [CChar](repeating: 0, count: Int(requiredCapacity))
        let written = buffer.withUnsafeMutableBufferPointer { pointer in
            guance_electron_bridge_configuration(pointer.baseAddress, requiredCapacity)
        }
        XCTAssertGreaterThan(written, 0)
        let json = String(cString: buffer)
        XCTAssertTrue(json.hasPrefix("{"))
    }
}
#endif
