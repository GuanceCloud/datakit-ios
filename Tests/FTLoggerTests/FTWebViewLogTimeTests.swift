import XCTest
@testable import _FTLogger

final class FTWebViewLogTimeTests: XCTestCase {
    func testInvalidBrowserDateUsesExplicitIngressTime() throws {
        let ingressTime: Int64 = 1_700_000_000_456_000_000
        let event = try XCTUnwrap(
            FTWebViewLogEventMapper.mapEvent(
                ["message": "invalid-browser-time", "date": "invalid"],
                fallbackNanosecondTime: ingressTime
            )
        )

        XCTAssertEqual(event.time, ingressTime)
    }
}
