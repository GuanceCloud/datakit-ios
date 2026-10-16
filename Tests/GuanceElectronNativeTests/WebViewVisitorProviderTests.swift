import XCTest
import GuanceSDK
import _GuanceSDKCore
import _FTProtocol

private final class NativeVisitorClock: NSObject {
    var date: Date
    init(date: Date) { self.date = date }
    @objc func now() -> Date { date }
}

final class WebViewVisitorProviderTests: XCTestCase {
    func testAgentSuppliesLiveNativeVisitorReader() throws {
        FTSDKAgent.shutDown()
        let key = "com.guance.sdk.visitor-id.record"
        let savedRecord = UserDefaults.standard.object(forKey: key)
        let knownID = "p0123456789abcdef0123456789abcdef"
        let createdAt = Date()
        UserDefaults.standard.set(["version": 1, "id": knownID,
            "createdAt": createdAt.timeIntervalSince1970], forKey: key)
        defer {
            FTSDKAgent.shutDown()
            if let savedRecord { UserDefaults.standard.set(savedRecord, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        let base = FTSDKConfig(datakitUrl: "http://127.0.0.1:9529")
        base.autoSync = false
        FTSDKAgent.start(withConfigOptions: base)
        let rum = FTRumConfig(appid: "visitor-provider-test")
        let visitor = FTVisitorIDConfig()
        visitor.header = "x-visitor"
        visitor.ttlHours = 1
        visitor.addMatch(urlPrefix: "https://api.example.com/")
        rum.visitorIDConfig = visitor
        FTSDKAgent.sharedInstance().startRum(withConfigOptions: rum)
        let handler = FTWKWebViewHandler.sharedInstance()
        let provider = try XCTUnwrap(handler.value(forKey: "visitorIDProvider") as? FTWebViewVisitorIDProvider)
        XCTAssertEqual(provider.currentVisitorID(), knownID)
        let object = provider as AnyObject as! NSObject
        let savedClock = object.value(forKey: "clock")
        let clock = NativeVisitorClock(date: createdAt.addingTimeInterval(3599))
        object.setValue(clock, forKey: "clock")
        defer { object.setValue(savedClock, forKey: "clock") }
        XCTAssertEqual(provider.currentVisitorID(), knownID)
        clock.date = createdAt.addingTimeInterval(3600)
        let expiredValue = try XCTUnwrap(provider.currentVisitorID())
        let expiredRecord = UserDefaults.standard.dictionary(forKey: key)
        XCTAssertEqual(expiredValue, expiredRecord?["id"] as? String)
        XCTAssertEqual(expiredRecord?["createdAt"] as? Double, clock.date.timeIntervalSince1970)
        XCTAssertNotEqual(expiredValue, knownID)
        FTSDKAgent.resetVisitorID()
        let persisted = try XCTUnwrap(UserDefaults.standard.dictionary(forKey: key)?["id"] as? String)
        XCTAssertEqual(provider.currentVisitorID(), persisted)
        XCTAssertNotEqual(persisted, expiredValue)
        FTSDKAgent.shutDown()
        XCTAssertNil(provider.currentVisitorID())
        XCTAssertNil(handler.value(forKey: "visitorIDProvider"))
    }
}
