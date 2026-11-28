//
//  ExternalReplayStartupTests.swift
//  GuanceElectronNativeTests
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//

#if os(macOS)
import XCTest
import GuanceSessionReplay

final class ExternalReplayStartupTests: XCTestCase {
    func testFractionalSamplingRatesStartExternalReplay() throws {
        // Rates are percentages: either 0.1% normal sampling or 0.2% error
        // sampling must initialize replay, even though legacy int getters return 0.
        for (normalRate, errorRate): (Float, Float) in [(0.1, 0), (0, 0.2)] {
            let replay = FTRumSessionReplay()
            let config = FTSessionReplayConfig()
            config.externalRecorderMode = true
            config.sessionReplaySamplingRate = normalRate
            config.sessionReplayOnErrorSamplingRate = errorRate

            replay.start(with: config)

            let features = try XCTUnwrap(replay.value(forKey: "features") as? [String: NSObject])
            XCTAssertEqual(Set(features.keys), ["session-replay", "session-replay-resources"])
            let feature = try XCTUnwrap(features["session-replay"])
            let activeConfig = try XCTUnwrap(feature.value(forKey: "config") as? FTSessionReplayConfig)
            XCTAssertEqual(activeConfig.sessionReplaySamplingRate, normalRate)
            XCTAssertEqual(activeConfig.sessionReplayOnErrorSamplingRate, errorRate)

            replay.start(with: config)
            let repeatedFeatures = try XCTUnwrap(replay.value(forKey: "features") as? [String: NSObject])
            XCTAssertTrue(repeatedFeatures["session-replay"] === feature)
        }
    }

    func testZeroSamplingRatesKeepExternalReplayDisabled() throws {
        let replay = FTRumSessionReplay()
        let config = FTSessionReplayConfig()
        config.externalRecorderMode = true
        config.sessionReplaySamplingRate = 0
        config.sessionReplayOnErrorSamplingRate = 0

        replay.start(with: config)

        let features = try XCTUnwrap(replay.value(forKey: "features") as? [String: NSObject])
        XCTAssertEqual(features.count, 0)
    }
}
#endif
