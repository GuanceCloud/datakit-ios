import AppKit
import JavaScriptCore
import WebKit
import XCTest
import _GuanceSDKCore
import _FTProtocol

private final class VisitorProvider: NSObject, FTWebViewVisitorIDProvider {
    var value: String?
    var reads = 0
    init(value: String?) { self.value = value }
    func currentVisitorID() -> String? {
        reads += 1
        return value
    }
}

private final class VisitorFrame: NSObject {
    var main = true
    @objc var isMainFrame: Bool { main }
    @objc var securityOrigin: WKSecurityOrigin {
        // WebKit has no public origin initializer. Supply the Objective-C host
        // getter used by the native bridge through a test double.
        unsafeBitCast(origin, to: WKSecurityOrigin.self)
    }
    var origin = VisitorOrigin()
}
private final class VisitorOrigin: NSObject {
    var testHost = "example.com"
    @objc var host: String { testHost }
}

private final class PromptDelegate: NSObject, WKUIDelegate {
    var count = 0
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        count += 1
        completionHandler("host-response")
    }
}

private final class VisitorNavigation: NSObject, WKNavigationDelegate {
    var finished: (() -> Void)?
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finished?() }
}

final class WebViewVisitorIDTests: XCTestCase {
    private let handler = FTWKWebViewHandler.sharedInstance()
    private var webView: WKWebView!
    private var provider: VisitorProvider?
    private let knownID = "p0123456789abcdef0123456789abcdef"

    override func setUp() {
        super.setUp()
        setProvider(nil)
        webView = WKWebView(frame: .zero)
    }
    override func tearDown() {
        handler.perform(NSSelectorFromString("disableWebView:"), with: webView)
        setProvider(nil)
        webView = nil
        super.tearDown()
    }
    private func setProvider(_ provider: VisitorProvider?) {
        self.provider = provider
        handler.setValue(provider, forKey: "visitorIDProvider")
    }
    private func enableVisitor() {
        setProvider(VisitorProvider(value: knownID))
    }
    private func install(hosts: [String]? = ["example.com"]) {
        handler.perform(NSSelectorFromString("enableWebView:allowWebViewHost:"), with: webView, with: hosts)
    }
    private func read(frame: VisitorFrame = VisitorFrame(), prompt: String = "FTWebViewJavascriptBridge.getVisitorid") -> String? {
        var calls = 0
        var result: String?
        webView.uiDelegate?.webView?(webView, runJavaScriptTextInputPanelWithPrompt: prompt,
            defaultText: "", initiatedByFrame: unsafeBitCast(frame, to: WKFrameInfo.self), completionHandler: { value in
                calls += 1
                result = value
            })
        XCTAssertEqual(calls, 1)
        return result
    }
    func testInstalledBridgeReadsCurrentProviderEveryTime() {
        // Install before RUM/provider setup, as with a Logger-only WebView.
        install()
        XCTAssertNil(read())
        enableVisitor()
        XCTAssertEqual(read(), knownID)
        provider?.value = "p11111111111111111111111111111111"
        XCTAssertEqual(read(), "p11111111111111111111111111111111")
        XCTAssertEqual(provider?.reads, 2)
        provider?.value = nil
        XCTAssertNil(read())
        setProvider(VisitorProvider(value: "s22222222222222222222222222222222"))
        XCTAssertEqual(read(), "s22222222222222222222222222222222")
        setProvider(nil)
        XCTAssertNil(read())
    }
    func testProviderIsWeakAndReleasedProviderReturnsNil() {
        install()
        weak var weakProvider: VisitorProvider?
        autoreleasepool {
            let transient = VisitorProvider(value: knownID)
            weakProvider = transient
            handler.setValue(transient, forKey: "visitorIDProvider")
            XCTAssertEqual(read(), knownID)
        }
        XCTAssertNil(weakProvider)
        XCTAssertNil(read())
    }
    func testHostAndFrameBoundaries() {
        enableVisitor()
        install()
        let frame = VisitorFrame()
        for host in ["example.com", "a.example.com", "EXAMPLE.COM"] {
            frame.origin.testHost = host
            XCTAssertEqual(read(frame: frame), knownID)
        }
        for host in ["example.com.evil.test", "evilexample.com", "", "other.test"] {
            frame.origin.testHost = host
            XCTAssertNil(read(frame: frame))
        }
        frame.origin.testHost = "example.com"
        frame.main = false
        XCTAssertNil(read(frame: frame))
        XCTAssertEqual(provider?.reads, 3, "Denied hosts and frames must not read the provider")
    }
    func testNilWhitelistAllowsMainFrameAndReleasedDelegateIsSafe() {
        enableVisitor()
        weak var weakDelegate: PromptDelegate?
        autoreleasepool {
            let delegate = PromptDelegate()
            weakDelegate = delegate
            webView.uiDelegate = delegate
            install(hosts: nil)
        }
        XCTAssertNil(weakDelegate)
        let frame = VisitorFrame()
        frame.origin.testHost = "any.test"
        XCTAssertEqual(read(frame: frame), knownID)
        XCTAssertNil(read(prompt: "ordinary prompt"))
        webView.uiDelegate = nil
        XCTAssertEqual(read(frame: frame), knownID)
    }
    func testRealWebViewReadsSynchronouslyAtDocumentStart() {
        enableVisitor()
        install()
        let navigation = VisitorNavigation()
        let loaded = expectation(description: "document loaded")
        navigation.finished = { loaded.fulfill() }
        webView.navigationDelegate = navigation
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = webView
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        webView.loadHTMLString("<html><script>window.idAtStart = FTWebViewJavascriptBridge.getVisitorid();</script></html>",
                               baseURL: URL(string: "https://example.com"))
        wait(for: [loaded], timeout: 15)
        let evaluated = expectation(description: "synchronous value")
        webView.evaluateJavaScript("window.idAtStart") { value, error in
            XCTAssertNil(error)
            XCTAssertEqual(value as? String, self.knownID)
            evaluated.fulfill()
        }
        wait(for: [evaluated], timeout: 5)
        withExtendedLifetime(navigation) {}
    }
    func testDisabledAndEmptyWhitelistReturnNoIdentifier() {
        install(hosts: [])
        XCTAssertNil(read())
        enableVisitor()
        XCTAssertNil(read())
    }
    func testDelegateReplacementForwardingAndRemoval() {
        let first = PromptDelegate()
        webView.uiDelegate = first
        install()
        XCTAssertEqual(read(prompt: "ordinary prompt"), "host-response")
        XCTAssertEqual(first.count, 1)
        let second = PromptDelegate()
        webView.uiDelegate = second
        XCTAssertEqual(read(prompt: "another prompt"), "host-response")
        XCTAssertEqual(second.count, 1)
        XCTAssertNil(read())
        XCTAssertEqual(second.count, 1)
        handler.perform(NSSelectorFromString("disableWebView:"), with: webView)
        XCTAssertTrue(webView.uiDelegate === second)
    }
    func testJavaScriptEntryPointIsSynchronousAndFailsClosed() {
        install()
        let source = webView.configuration.userContentController.userScripts.first {
            $0.source.hasPrefix("/* FTWebViewJavascriptBridge */")
        }!.source
        let context = JSContext()!
        context.evaluateScript("var window = this; window.prompt = function() { return '\(knownID)'; };")
        context.evaluateScript(source)
        XCTAssertNil(context.exception)
        XCTAssertEqual(context.evaluateScript("FTWebViewJavascriptBridge.getVisitorid()")?.toString(), knownID)
        for body in ["return null", "return ''", "return 42", "throw new Error('read failed')"] {
            context.evaluateScript("window.prompt = function() { \(body); };")
            XCTAssertTrue(context.evaluateScript("FTWebViewJavascriptBridge.getVisitorid()")!.isNull)
        }
        context.evaluateScript("delete window.prompt")
        XCTAssertTrue(context.evaluateScript("FTWebViewJavascriptBridge.getVisitorid()")!.isNull)
    }
}
