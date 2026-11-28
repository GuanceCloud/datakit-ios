# OrbitDesk — Native-owned external mode

This example keeps the AppKit Native Host and Electron business surfaces as separate processes. The Swift host owns SDK configuration and starts `FTElectronBridgeServer`; the Electron Main process connects with `native.mode: "external"` before creating its first BrowserWindow.

The Swift host depends on the Native SDK in the containing checkout. The relative path resolves from `native/macos/` to the repository root:

```swift
.package(
    name: "datakit-ios",
    path: "../../../../.."
)
```

Its target depends on `GuanceSDK`, `GuanceElectronWebView`, and `GuanceSessionReplay`. The host initializes the SDK, RUM, and Logger, starts and retains the Bridge Server, optionally starts Session Replay, and passes the server's socket credentials to the Electron child. This mode does not require the `GuanceElectronNative` product or an npm-built Native runtime.

Follow the [workspace prerequisites](../README.md#prerequisites), then run from this directory:

```sh
cp .env.example .env.local
npm install
npm run dev
```

Fill in `.env.local` with a Native RUM application ID and a DataKit endpoint, or a DataWay endpoint and client token, before starting the application.

The development command builds the Swift host and an accessory Electron app, starts Vite, and launches the Native-owned application. Browser RUM and Browser Logs use bridge-only defaults and forward Renderer events to the Native SDK. Native SDK options, including `GUANCE_NATIVE_ACTION_TRACKING` and `GUANCE_NATIVE_LOGGING`, remain in the Swift host; no `native.settings` object is passed to Electron. Native Logger and Session Replay sampling values use the Apple SDK's `0..100` units. Browser Logs starts only when the Native bridge advertises its `log` capability.

Run the host tests and automated startup check with:

```sh
npm run native:test
npm run smoke
```
