import AppKit
import ObjectiveC.runtime
import XCTest
import _GuanceSDKCore
import _FTRUM
import _FTProtocol
@testable import GuanceElectronWebView

@objc(WebContentsViewCocoa)
private final class TestWebContentsView: NSView {}

final class GuanceElectronWebViewTests: XCTestCase {
    private let handler = FTElectronWebViewHandler.sharedInstance()

    override func setUp() {
        super.setUp()
        handler.removeAllRegistrations()
        handler.start(command: nil)
    }

    override func tearDown() {
        handler.removeAllRegistrations()
        super.tearDown()
    }

    func testRegistersMultipleWebContentsWithIndependentSlots() {
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))

        XCTAssertTrue(
            handler.registerWebContentsID(
                11,
                slotID: 1001,
                hostView: host,
                bounds: CGRect(x: 0, y: 0, width: 450, height: 600),
                visible: true,
                zIndex: 0
            )
        )
        XCTAssertTrue(
            handler.registerWebContentsID(
                12,
                slotID: 1002,
                hostView: host,
                bounds: CGRect(x: 450, y: 0, width: 450, height: 600),
                visible: true,
                zIndex: 1
            )
        )

        XCTAssertEqual(handler.registeredWebContentsCount(), 2)
        XCTAssertEqual(handler.slotID(forWebContentsID: 11), 1001)
        XCTAssertEqual(handler.slotID(forWebContentsID: 12), 1002)
    }

    func testStandaloneRegistrationAllocatesNativeSlotsWithoutAppKitViews() {
        let firstSlot = handler.registerStandaloneWebContentsID(
            13,
            visible: true
        )
        let secondSlot = handler.registerStandaloneWebContentsID(
            14,
            visible: false
        )

        XCTAssertNotNil(firstSlot)
        XCTAssertNotNil(secondSlot)
        XCTAssertNotEqual(firstSlot, secondSlot)
        XCTAssertEqual(handler.slotID(forWebContentsID: 13), firstSlot)
        XCTAssertEqual(handler.slotID(forWebContentsID: 14), secondSlot)
        XCTAssertEqual(handler.registeredWebContentsCount(), 2)
        XCTAssertEqual(handler.matchedNativeViewCount(), 0)
        XCTAssertTrue(
            handler.receiveMessageQueue(
                #"[{"handlerName":"sendEvent","data":{"name":"rum"}}]"#,
                webContentsID: 13
            )
        )
        XCTAssertFalse(
            handler.receiveMessageQueue(
                #"[{"handlerName":"sendEvent","data":{"name":"rum"}}]"#,
                webContentsID: 14
            )
        )
        XCTAssertTrue(
            handler.updateStandaloneWebContentsID(14, visible: true)
        )
        XCTAssertTrue(
            handler.receiveMessageQueue(
                #"[{"handlerName":"sendEvent","data":{"name":"rum"}}]"#,
                webContentsID: 14
            )
        )
    }

    func testStandaloneFullSnapshotCommandTargetsOnlyVisibleRegistrations() throws {
        var commands: [(Int64, String)] = []
        handler.start { webContentsID, command in
            commands.append((webContentsID, command))
        }
        XCTAssertNotNil(
            handler.registerStandaloneWebContentsID(15, visible: true)
        )
        XCTAssertNotNil(
            handler.registerStandaloneWebContentsID(16, visible: false)
        )

        try invokeTakeSubsequentFullSnapshot()

        XCTAssertEqual(commands.count, 1)
        XCTAssertEqual(commands.first?.0, 15)
        XCTAssertEqual(
            commands.first?.1,
            FTElectronWebViewCommandTakeSubsequentFullSnapshot
        )
    }

    func testRejectsUnknownSenderAndRemovesRegistration() {
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 500))
        XCTAssertTrue(
            handler.registerWebContentsID(
                21,
                slotID: 2001,
                hostView: host,
                bounds: host.bounds,
                visible: true,
                zIndex: 0
            )
        )

        XCTAssertFalse(
            handler.receiveMessageQueue(
                #"[{"handlerName":"sendEvent","data":{"name":"rum"}}]"#,
                webContentsID: 999
            )
        )

        handler.unregisterWebContentsID(21)
        XCTAssertNil(handler.slotID(forWebContentsID: 21))
        XCTAssertEqual(handler.registeredWebContentsCount(), 0)
    }

    func testRejectsInvalidBoundsAndMalformedBridgePayload() {
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 500))

        XCTAssertFalse(
            handler.registerWebContentsID(
                31,
                slotID: 3001,
                hostView: host,
                bounds: .zero,
                visible: true,
                zIndex: 0
            )
        )

        XCTAssertTrue(
            handler.registerWebContentsID(
                31,
                slotID: 3001,
                hostView: host,
                bounds: host.bounds,
                visible: true,
                zIndex: 0
            )
        )
        XCTAssertFalse(
            handler.receiveMessageQueue("not-json", webContentsID: 31)
        )
        XCTAssertFalse(
            handler.receiveMessageQueue(
                #"[{"handlerName":"unknown","data":{}}]"#,
                webContentsID: 31
            )
        )
    }

    func testRoutesOnlySendEventMessagesForRegisteredSender() {
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 500))
        XCTAssertTrue(
            handler.registerWebContentsID(
                41,
                slotID: 4001,
                hostView: host,
                bounds: host.bounds,
                visible: true,
                zIndex: 0
            )
        )

        XCTAssertTrue(
            handler.receiveMessageQueue(
                #"[{"handlerName":"sendEvent","data":{"name":"session_replay","data":{"records":[]}}}]"#,
                webContentsID: 41
            )
        )
    }

    func testUpdatesLayoutAndUnregistersAllContentsForHost() {
        let firstHost = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 500))
        let secondHost = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 500))
        XCTAssertTrue(
            handler.registerWebContentsID(
                51,
                slotID: 5001,
                hostView: firstHost,
                bounds: firstHost.bounds,
                visible: true,
                zIndex: 0
            )
        )
        XCTAssertTrue(
            handler.registerWebContentsID(
                52,
                slotID: 5002,
                hostView: firstHost,
                bounds: firstHost.bounds,
                visible: true,
                zIndex: 1
            )
        )
        XCTAssertTrue(
            handler.registerWebContentsID(
                53,
                slotID: 5003,
                hostView: secondHost,
                bounds: secondHost.bounds,
                visible: true,
                zIndex: 0
            )
        )

        XCTAssertTrue(
            handler.updateWebContentsID(
                51,
                bounds: CGRect(x: 20, y: 10, width: 700, height: 400),
                visible: false,
                zIndex: 2
            )
        )
        XCTAssertFalse(
            handler.updateWebContentsID(
                999,
                bounds: firstHost.bounds,
                visible: true,
                zIndex: 0
            )
        )

        handler.unregisterHostView(firstHost)
        XCTAssertNil(handler.slotID(forWebContentsID: 51))
        XCTAssertNil(handler.slotID(forWebContentsID: 52))
        XCTAssertEqual(handler.slotID(forWebContentsID: 53), 5003)
    }

    func testRejectsPayloadLargerThanOneMegabyte() {
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 500))
        XCTAssertTrue(
            handler.registerWebContentsID(
                61,
                slotID: 6001,
                hostView: host,
                bounds: host.bounds,
                visible: true,
                zIndex: 0
            )
        )

        let oversizedPayload = String(repeating: "x", count: 1024 * 1024 + 1)
        XCTAssertFalse(
            handler.receiveMessageQueue(oversizedPayload, webContentsID: 61)
        )
    }

    func testBridgeConfigurationUsesSafeDefaults() throws {
        try configureNativeWebView(
            FTWKWebViewHandler.sharedInstance(),
            enabled: false,
            allowedHosts: nil
        )
        let configuration = handler.bridgeConfiguration()

        XCTAssertEqual(configuration["enableTraceWebView"] as? Bool, false)
        XCTAssertTrue(configuration["allowedWebViewHosts"] is NSNull)
        XCTAssertNotNil(configuration["capabilities"] as? String)
        XCTAssertNotNil(configuration["privacyLevel"] as? String)
        XCTAssertEqual(configuration["maximumMessageBytes"] as? Int, 1024 * 1024)
    }

    func testBridgeConfigurationReusesNativeWebViewRUMOptions() throws {
        let nativeHandler = FTWKWebViewHandler.sharedInstance()
        try configureNativeWebView(
            nativeHandler,
            enabled: true,
            allowedHosts: ["example.com", "internal.test"]
        )

        let configuration = handler.bridgeConfiguration()

        XCTAssertEqual(configuration["enableTraceWebView"] as? Bool, true)
        XCTAssertEqual(
            configuration["allowedWebViewHosts"] as? [String],
            ["example.com", "internal.test"]
        )
    }

    func testParameterlessStartPreservesBridgeCommandHandler() throws {
        var commands: [(Int64, String)] = []
        handler.start { webContentsID, command in
            commands.append((webContentsID, command))
        }

        handler.start()

        let host = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 500))
        let window = NSWindow(
            contentRect: host.bounds,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.addSubview(TestWebContentsView(frame: host.bounds))

        XCTAssertTrue(
            handler.registerWebContentsID(
                72,
                slotID: 7002,
                hostView: host,
                bounds: host.bounds,
                visible: true,
                zIndex: 0
            )
        )

        // A full snapshot is only meaningful after the native recorder has
        // associated this Chromium view with its native wireframe slot.
        _ = try takeSessionReplaySnapshot(rootView: host)
        commands.removeAll()
        try invokeTakeSubsequentFullSnapshot()

        XCTAssertEqual(commands.count, 1)
        XCTAssertEqual(commands.first?.0, 72)
        XCTAssertEqual(
            commands.first?.1,
            FTElectronWebViewCommandTakeSubsequentFullSnapshot
        )
        withExtendedLifetime(window) {}
    }

    func testActiveNativeViewBecomesWebContainerWhenReplayStateArrivesLater() throws {
        let dependencies = FTRUMDependencies()
        dependencies.appId = "electron-container-test"
        dependencies.sampleRate = 100
        let rumManager = FTRUMManager(rumDependencies: dependencies)

        rumManager.startView(
            withViewID: "native-view-before-replay",
            viewName: "Hybrid Window",
            property: nil
        )
        rumManager.syncProcess()
        XCTAssertTrue(rumManager.getLastHasReplayViewID().isEmpty)

        try sendModuleMessage(
            to: rumManager,
            key: FTMessageKey.sessionHasReplay.rawValue as NSString,
            message: [
                FT_SESSION_HAS_REPLAY: true,
                FT_RUM_KEY_SAMPLED_FOR_ERROR_REPLAY: false,
            ]
        )
        rumManager.syncProcess()

        XCTAssertEqual(
            rumManager.getLastHasReplayViewID(),
            "native-view-before-replay"
        )
    }

    func testMatchesSameFrameViewsByNativeOrderWithinOneContainer() throws {
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertEqual(NSStringFromClass(TestWebContentsView.self), "WebContentsViewCocoa")

        let root = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 500))
        let window = NSWindow(
            contentRect: root.bounds,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.contentView = root
        root.addSubview(TestWebContentsView(frame: root.bounds))
        root.addSubview(TestWebContentsView(frame: root.bounds))
        let electronViews = root.subviews

        XCTAssertTrue(
            handler.registerWebContentsID(
                71,
                slotID: 7001,
                hostView: root,
                bounds: root.bounds,
                visible: true,
                zIndex: 0
            )
        )
        XCTAssertTrue(
            handler.registerWebContentsID(
                72,
                slotID: 7002,
                hostView: root,
                bounds: root.bounds,
                visible: true,
                zIndex: 1
            )
        )

        let firstDescriptor = try descriptor(
            for: electronViews[0],
            frame: root.bounds
        )
        let secondDescriptor = try descriptor(
            for: electronViews[1],
            frame: root.bounds
        )

        XCTAssertEqual(firstDescriptor?.value(forKey: "slotID") as? Int64, 7001)
        XCTAssertEqual(secondDescriptor?.value(forKey: "slotID") as? Int64, 7002)
        XCTAssertEqual(handler.matchedNativeViewCount(), 2)
        withExtendedLifetime(window) {}
    }

    func testMatchesIndependentNativeContainersWithoutWindowLevelGuessing() throws {
        XCTAssertTrue(Thread.isMainThread)

        let root = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 500))
        let window = NSWindow(
            contentRect: root.bounds,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.contentView = root

        // The two H5 containers intentionally use identical geometry. Their
        // Native controller roots, not bounds or their common NSWindow, are
        // the primary identity boundary.
        let firstContainer = NSView(frame: root.bounds)
        let secondContainer = NSView(frame: root.bounds)
        let firstElectronView = TestWebContentsView(frame: firstContainer.bounds)
        let secondElectronView = TestWebContentsView(frame: secondContainer.bounds)
        firstContainer.addSubview(firstElectronView)
        secondContainer.addSubview(secondElectronView)
        root.addSubview(firstContainer)
        root.addSubview(secondContainer)

        XCTAssertTrue(
            handler.registerWebContentsID(
                75,
                slotID: 7005,
                hostView: firstContainer,
                bounds: root.bounds,
                visible: true,
                zIndex: 99
            )
        )
        XCTAssertTrue(
            handler.registerWebContentsID(
                76,
                slotID: 7006,
                hostView: secondContainer,
                bounds: root.bounds,
                visible: true,
                zIndex: -99
            )
        )

        let firstDescriptor = try descriptor(
            for: firstElectronView,
            frame: firstElectronView.frame
        )
        let secondDescriptor = try descriptor(
            for: secondElectronView,
            frame: secondElectronView.frame
        )

        XCTAssertEqual(firstDescriptor?.value(forKey: "slotID") as? Int64, 7005)
        XCTAssertEqual(secondDescriptor?.value(forKey: "slotID") as? Int64, 7006)
        XCTAssertEqual(handler.matchedNativeViewCount(), 2)
        withExtendedLifetime(window) {}
    }

    func testHiddenNativeContainerClearsCachedWebContentsAssociation() throws {
        XCTAssertTrue(Thread.isMainThread)

        let root = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 500))
        let window = NSWindow(
            contentRect: root.bounds,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.contentView = root
        let container = NSView(frame: root.bounds)
        let electronView = TestWebContentsView(frame: container.bounds)
        container.addSubview(electronView)
        root.addSubview(container)

        XCTAssertTrue(
            handler.registerWebContentsID(
                77,
                slotID: 7007,
                hostView: container,
                bounds: container.bounds,
                visible: true,
                zIndex: 0
            )
        )
        XCTAssertNotNil(try descriptor(for: electronView, frame: electronView.frame))
        XCTAssertEqual(handler.matchedNativeViewCount(), 1)

        container.isHidden = true
        XCTAssertNil(try descriptor(for: electronView, frame: electronView.frame))
        XCTAssertEqual(handler.matchedNativeViewCount(), 0)

        container.isHidden = false
        XCTAssertEqual(
            (try descriptor(for: electronView, frame: electronView.frame))?
                .value(forKey: "slotID") as? Int64,
            7007
        )
        XCTAssertEqual(handler.matchedNativeViewCount(), 1)
        withExtendedLifetime(window) {}
    }

    func testSingleWindowContainerUsesItsNativeWireframeWithoutBoundsMatching() throws {
        XCTAssertTrue(Thread.isMainThread)

        let root = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 500))
        let window = NSWindow(
            contentRect: root.bounds,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.contentView = root
        let electronView = TestWebContentsView(
            frame: NSRect(x: 180, y: 60, width: 560, height: 380)
        )
        root.addSubview(electronView)

        XCTAssertTrue(
            handler.registerWebContentsID(
                73,
                slotID: 7003,
                hostView: root,
                // BrowserWindow registration does not need Chromium bounds.
                // Its Native host bounds intentionally differ from the view.
                bounds: root.bounds,
                visible: true,
                zIndex: 0
            )
        )

        let snapshot = try takeSessionReplaySnapshot(rootView: root)
        let slotIDs = snapshot.value(forKey: "webViewSlotIDs") as? Set<NSNumber>

        XCTAssertEqual(slotIDs, [7003])
        XCTAssertEqual(handler.matchedNativeViewCount(), 1)
        withExtendedLifetime(window) {}
    }

    func testSubsequentSnapshotTargetsOnlyVisibleAttachedRegistrations() throws {
        XCTAssertTrue(Thread.isMainThread)
        var commands: [(Int64, String)] = []
        handler.start { webContentsID, command in
            commands.append((webContentsID, command))
        }

        let attachedHost = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 500))
        let window = NSWindow(
            contentRect: attachedHost.bounds,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.contentView = attachedHost
        attachedHost.addSubview(TestWebContentsView(frame: attachedHost.bounds))
        let detachedHost = NSView(frame: attachedHost.bounds)

        XCTAssertTrue(
            handler.registerWebContentsID(
                81,
                slotID: 8001,
                hostView: attachedHost,
                bounds: attachedHost.bounds,
                visible: true,
                zIndex: 0
            )
        )
        XCTAssertTrue(
            handler.registerWebContentsID(
                82,
                slotID: 8002,
                hostView: attachedHost,
                bounds: attachedHost.bounds,
                visible: false,
                zIndex: 1
            )
        )
        XCTAssertTrue(
            handler.registerWebContentsID(
                83,
                slotID: 8003,
                hostView: detachedHost,
                bounds: detachedHost.bounds,
                visible: true,
                zIndex: 0
            )
        )

        _ = try takeSessionReplaySnapshot(rootView: attachedHost)
        commands.removeAll()
        try invokeTakeSubsequentFullSnapshot()

        XCTAssertEqual(commands.count, 1)
        XCTAssertEqual(commands.first?.0, 81)
        XCTAssertEqual(
            commands.first?.1,
            FTElectronWebViewCommandTakeSubsequentFullSnapshot
        )
        withExtendedLifetime(window) {}
    }

    func testBecomingVisibleRequestsOneFullSnapshotAfterNativeSlotIsCaptured() throws {
        XCTAssertTrue(Thread.isMainThread)
        var commands: [(Int64, String)] = []
        handler.start { webContentsID, command in
            commands.append((webContentsID, command))
        }

        let host = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 500))
        let window = NSWindow(
            contentRect: host.bounds,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.addSubview(TestWebContentsView(frame: host.bounds))

        XCTAssertTrue(
            handler.registerWebContentsID(
                84,
                slotID: 8004,
                hostView: host,
                bounds: host.bounds,
                visible: false,
                zIndex: 0
            )
        )

        XCTAssertTrue(
            handler.updateWebContentsID(
                84,
                bounds: host.bounds,
                visible: true,
                zIndex: 0
            )
        )
        XCTAssertEqual(commands.count, 0)

        _ = try takeSessionReplaySnapshot(rootView: host)
        XCTAssertEqual(commands.count, 1)
        XCTAssertEqual(commands.first?.0, 84)
        XCTAssertEqual(
            commands.first?.1,
            FTElectronWebViewCommandTakeSubsequentFullSnapshot
        )

        XCTAssertTrue(
            handler.updateWebContentsID(
                84,
                bounds: CGRect(x: 10, y: 0, width: 790, height: 500),
                visible: true,
                zIndex: 1
            )
        )
        _ = try takeSessionReplaySnapshot(rootView: host)
        XCTAssertEqual(commands.count, 1)

        XCTAssertTrue(
            handler.updateWebContentsID(
                84,
                bounds: host.bounds,
                visible: false,
                zIndex: 0
            )
        )
        XCTAssertTrue(
            handler.updateWebContentsID(
                84,
                bounds: host.bounds,
                visible: true,
                zIndex: 0
            )
        )
        XCTAssertEqual(commands.count, 1)
        _ = try takeSessionReplaySnapshot(rootView: host)
        XCTAssertEqual(commands.count, 2)
        XCTAssertEqual(commands.last?.0, 84)
        withExtendedLifetime(window) {}
    }

    func testSessionReplaySnapshotCollectsRegisteredElectronSlot() throws {
        XCTAssertTrue(Thread.isMainThread)
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 500))
        let window = NSWindow(
            contentRect: root.bounds,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.contentView = root
        root.addSubview(TestWebContentsView(frame: root.bounds))

        XCTAssertTrue(
            handler.registerWebContentsID(
                91,
                slotID: 9001,
                hostView: root,
                bounds: root.bounds,
                visible: true,
                zIndex: 0
            )
        )

        let snapshot = try takeSessionReplaySnapshot(rootView: root)
        let slotIDs = snapshot.value(forKey: "webViewSlotIDs") as? Set<NSNumber>

        XCTAssertEqual(slotIDs, [9001])
        XCTAssertEqual(handler.matchedNativeViewCount(), 1)
        withExtendedLifetime(window) {}
    }

    private func descriptor(for view: NSView, frame: CGRect) throws -> NSObject? {
        let selector = NSSelectorFromString("descriptorForNativeView:frame:")
        guard let method = class_getInstanceMethod(
            FTElectronWebViewHandler.self,
            selector
        ) else {
            throw TestError.missingRuntimeMethod
        }
        typealias Matcher = @convention(c) (
            AnyObject,
            Selector,
            NSView,
            CGRect
        ) -> Unmanaged<AnyObject>?
        let matcher = unsafeBitCast(method_getImplementation(method), to: Matcher.self)
        return matcher(handler, selector, view, frame)?.takeUnretainedValue() as? NSObject
    }

    private func configureNativeWebView(
        _ nativeHandler: FTWKWebViewHandler,
        enabled: Bool,
        allowedHosts: [String]?
    ) throws {
        let hostsSelector = NSSelectorFromString("setAllowWebViewHost:")
        guard let hostsMethod = class_getInstanceMethod(
            FTWKWebViewHandler.self,
            hostsSelector
        ) else {
            throw TestError.missingRuntimeMethod
        }
        typealias HostsInvocation = @convention(c) (
            AnyObject,
            Selector,
            NSArray?
        ) -> Void
        let setHosts = unsafeBitCast(
            method_getImplementation(hostsMethod),
            to: HostsInvocation.self
        )
        setHosts(
            nativeHandler,
            hostsSelector,
            allowedHosts as NSArray?
        )

        let rumSelector = NSSelectorFromString("startWithEnableTraceWebView:rumDelegate:")
        guard let rumMethod = class_getInstanceMethod(
            FTWKWebViewHandler.self,
            rumSelector
        ) else {
            throw TestError.missingRuntimeMethod
        }
        typealias RUMInvocation = @convention(c) (
            AnyObject,
            Selector,
            Bool,
            AnyObject?
        ) -> Void
        let startRUM = unsafeBitCast(
            method_getImplementation(rumMethod),
            to: RUMInvocation.self
        )
        startRUM(
            nativeHandler,
            rumSelector,
            enabled,
            nil
        )
    }

    private func invokeTakeSubsequentFullSnapshot() throws {
        let selector = NSSelectorFromString("takeSubsequentFullSnapshot")
        guard let method = class_getInstanceMethod(
            FTElectronWebViewHandler.self,
            selector
        ) else {
            throw TestError.missingRuntimeMethod
        }
        typealias Invocation = @convention(c) (AnyObject, Selector) -> Void
        let invocation = unsafeBitCast(
            method_getImplementation(method),
            to: Invocation.self
        )
        invocation(handler, selector)
    }

    private func sendModuleMessage(
        to receiver: NSObject,
        key: NSString,
        message: NSDictionary
    ) throws {
        let selector = NSSelectorFromString("receive:message:")
        guard let method = class_getInstanceMethod(type(of: receiver), selector) else {
            throw TestError.missingRuntimeMethod
        }
        typealias Invocation = @convention(c) (
            AnyObject,
            Selector,
            NSString,
            NSDictionary
        ) -> Void
        let invocation = unsafeBitCast(
            method_getImplementation(method),
            to: Invocation.self
        )
        invocation(receiver, selector, key, message)
    }

    private func takeSessionReplaySnapshot(rootView: NSView) throws -> NSObject {
        guard
            let builderType = NSClassFromString("FTViewTreeSnapshotBuilder")
                as? NSObject.Type,
            let contextType = NSClassFromString("FTSRContext") as? NSObject.Type
        else {
            throw TestError.missingRuntimeClass
        }
        let builder = builderType.init()
        let context = contextType.init()
        context.setValue(Date(), forKey: "date")

        let selector = NSSelectorFromString(
            "takeSnapshot:referenceView:context:"
        )
        guard let method = class_getInstanceMethod(builderType, selector) else {
            throw TestError.missingRuntimeMethod
        }
        typealias SnapshotInvocation = @convention(c) (
            AnyObject,
            Selector,
            NSArray,
            NSView,
            AnyObject
        ) -> Unmanaged<AnyObject>?
        let invocation = unsafeBitCast(
            method_getImplementation(method),
            to: SnapshotInvocation.self
        )
        guard let snapshot = invocation(
            builder,
            selector,
            [rootView] as NSArray,
            rootView,
            context
        )?.takeUnretainedValue() as? NSObject else {
            throw TestError.missingSnapshot
        }
        return snapshot
    }

    private enum TestError: Error {
        case missingRuntimeClass
        case missingRuntimeMethod
        case missingSnapshot
    }
}
