# macOS Native + Electron Quick Start

Use this guide when a macOS Native application embeds Electron pages.

Copy this `GuanceElectronRUM` directory into the Electron project.

This directory includes a precompiled universal macOS
`GuanceElectronBridge.node` for `arm64` and `x86_64`. It is a Main-process
adapter, not a second Native SDK: it calls the already-loaded
`FTElectronWebViewHandler` in the same process and never initializes Guance SDK
products.

## 1. Install the Native SDK

### Recommended: Swift Package Manager

In Xcode, choose **File > Add Package Dependencies**, add the Guance SDK
package, then add these library products to the macOS application target:

- `GuanceSDK`
- `GuanceSessionReplay`
- `GuanceElectronWebView`

### CocoaPods

If the Native application uses CocoaPods, add the following to its `Podfile`:

```ruby
platform :osx, '10.14'

pod 'GuanceSDK'
pod 'GuanceSDK/SessionReplay'
pod 'GuanceSDK/ElectronWebView'
```

Run `pod install` and open the generated `.xcworkspace`.

### Manual framework integration

For projects that cannot use a package manager, link the same three macOS
frameworks manually: `GuanceSDK`, `GuanceSessionReplay`, and
`GuanceElectronWebView`.

## 2. Initialize the Native SDK

Initialize Native RUM, start the Electron handler, then start Native Session
Replay.

```objc
#import <GuanceSDK/FTSDKAgent.h>
#import <GuanceSessionReplay/FTRumSessionReplay.h>
#import <GuanceElectronWebView/GuanceElectronWebView.h>

FTSDKConfig *sdkConfig = [[FTSDKConfig alloc]
    initWithDatawayUrl:@"https://openway.example.com"
          clientToken:@"<client-token>"];
[FTSDKAgent startWithConfigOptions:sdkConfig];

FTRumConfig *rumConfig = [[FTRumConfig alloc] initWithAppid:@"<native-app-id>"];
rumConfig.enableTraceUserView = YES;
[[FTSDKAgent sharedInstance] startRumWithConfigOptions:rumConfig];

[[FTElectronWebViewHandler sharedInstance] start];

FTSessionReplayConfig *replayConfig = [FTSessionReplayConfig new];
replayConfig.sampleRate = 100;
[[FTRumSessionReplay sharedInstance]
    startWithSessionReplayConfig:replayConfig];
```

Configuration:

- `enableTraceWebView = YES`: automatically collects Electron windows and
  BrowserViews.
- `allowWebViewHost = nil` or `@[]`: collects all H5 hosts.
- `allowWebViewHost = @[@"example.com"]`: collects `example.com` and its
  subdomains.

## 3. Initialize once in Electron Main

Call `bootstrap` before the first Electron page calls `loadURL()` or
`loadFile()`. The `BrowserWindow` may be created before or after `bootstrap`.

```js
const { app, BrowserWindow } = require('electron')
const GuanceElectronRUM = require('./GuanceElectronRUM/main.cjs')
const nativeBridge = require('./GuanceElectronRUM/GuanceElectronBridge.node')

app.whenReady().then(() => {
  GuanceElectronRUM.bootstrap({ nativeBridge })

  const mainWindow = new BrowserWindow({
    webPreferences: { contextIsolation: true },
  })
  mainWindow.loadURL(mainURL)
})
```

No extra call is needed for subsequent `BrowserWindow` or `BrowserView`
instances.

### WebContents requirement

`contextIsolation` is configured per WebContents and is enabled by default in
current Electron releases. No extra configuration is required when the
application keeps that default. Every `BrowserWindow` and `BrowserView` that
loads an H5 page collected by Guance must keep `contextIsolation` enabled.

If the application explicitly disables it, restore it for the affected window
or view:

```js
const detailWindow = new BrowserWindow({
  webPreferences: { contextIsolation: true },
})

const contentView = new BrowserView({
  webPreferences: { contextIsolation: true },
})
```

This allows the Guance preload to expose its restricted bridge without giving
the H5 page direct Electron IPC access. A legacy page that depends on
`contextIsolation: false` keeps running, but Guance skips bridge injection and
prints a warning in that renderer's DevTools. Web RUM and Web Session Replay
are not collected for that page.

For a release build, sign `GuanceElectronBridge.node` with the same signing
workflow as the application. The bridge source and rebuild script are kept in
the integration example; rebuild only when its Node-API surface, required
architecture, or Electron compatibility changes.

To collect only selected windows, disable automatic attachment and attach the
window before loading its page:

```js
const electronRUM = GuanceElectronRUM.bootstrap({
  nativeBridge,
  autoAttach: false,
})

const detailWindow = new BrowserWindow(detailOptions)
electronRUM.attachWindow(detailWindow)
detailWindow.loadURL(detailURL)
```

## 4. Initialize the Web SDK in every H5 page

Initialize the Guance Web SDK normally, then start Web Session Replay.

```js
import { datafluxRum } from '@cloudcare/browser-rum'

datafluxRum.init({
  applicationId: '<web-app-id>',
  datakitOrigin: 'https://datakit.example.com',
  service: 'desktop-electron',
  env: 'production',
  sessionReplaySampleRate: 100,
})

datafluxRum.startSessionReplayRecording()
```

Do not add Electron-specific bridge code in the H5 page.

## 5. Verify

1. Open an Electron page and run this in its DevTools:

   ```js
   Boolean(window.FTWebViewJavascriptBridge)
   ```

   The result should be `true`.

2. Trigger an H5 action or request. New Native and H5 RUM events should have
   the same uploaded `session_id`.

3. Trigger Native and H5 interactions. Session Replay should contain both.
