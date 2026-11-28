# Real Browser SDK Visitor ID integration

This standalone test App links the current iOS Simulator SDK framework and loads the **unmodified npm 3.3.16 full and slim bundles** in WKWebView. Published archive SHA-256 hashes are pinned in `run.py`. Bundles are downloaded into a temporary output directory, not committed.

The local HTTP server listens only on `127.0.0.1:18763`. Actual XHR and Fetch requests reach this server; JSON responses echo the received headers. Browser `beforeSend` observes real RUM events without changing them. Native RUM starts normally with `autoSync = NO`; no production telemetry endpoint or credentials are used. Bridge event observation forwards all original events to the SDK.

## Run

Use a booted iOS simulator UDID from `xcrun simctl list devices booted`. Python 3, Xcode, Ruby and the `xcodeproj` gem are required. The runner builds the SDK unless `--framework` points to a current-branch iOS Simulator framework.

```sh
python3 Tests/WebViewVisitorIDIntegration/run.py --device SIMULATOR_UDID
```

For a CocoaPods-bundled Ruby environment:

```sh
GEM_HOME=/opt/homebrew/Cellar/cocoapods/1.16.2_1/libexec \
python3 Tests/WebViewVisitorIDIntegration/run.py \
  --ruby /opt/homebrew/opt/ruby/bin/ruby --device SIMULATOR_UDID
```

The App uses its own bundle ID `com.guance.webvisitor.integration`, UserDefaults and nonpersistent website data stores. It adopts the Scene lifecycle and makes each WKWebView first responder before initializing Browser RUM. Browser RUM's WebView lifecycle uses `document.hasFocus()`; initializing an unfocused test WebView would end its View before Action/Resource checks. No synthetic browser focus events are injected.

## Assertions

Both bundles execute eight scenarios: native identity, missing getter, invalid header-unsafe return, thrown getter, denied domain, native Visitor ID disabled, Web Visitor ID disabled, and no native bridge.

Assertions compare exact server-observed XHR/Fetch header values with RUM Action and Resource `context.visitor_id`. Unmatched requests must have no Visitor header. Fallback scenarios start with a known valid Web storage record and must reuse that exact identifier; Web reset then rotates it. The native case additionally verifies:

- Web reset preserves the App ID.
- Native reset changes the next request and RUM event to the current App ID.
- Real in-flight XHR/Fetch requests are held by server-side events. Native reset occurs after both reach the server, then responses are released. Completed Resource events retain the request-time ID; later requests use the new ID.
- A controlled native clock expires the native TTL without waiting; the next request/event uses the replacement ID.
- Disabling the native Visitor manager falls back to Browser identity.

Results, request headers, local intake payloads and build logs remain in the printed temporary output directory. The runner exits nonzero for any failed assertion, missing case or timeout. This is an iOS Simulator test, not a physical-device test or backend-ingestion test.
