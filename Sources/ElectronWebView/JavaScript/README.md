# macOS Native + Electron Quick Start

Use this guide when a macOS Native application embeds Electron pages.

Copy this `JavaScript` directory into the Electron project as
`GuanceElectronRUM`.

This directory includes a precompiled universal macOS
`GuanceElectronBridge.node` for `arm64` and `x86_64`. It is a Main-process
adapter, not a second Native SDK: it calls the already-loaded
`FTElectronWebViewHandler` in the same process and never initializes Guance SDK
products.

## 1. Add Native SDK products

Add these macOS products to the Native application:

- `GuanceSDK`
- `GuanceSessionReplay`
- `GuanceElectronWebView`

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
rumConfig.enableTraceWebView = YES;
rumConfig.allowWebViewHost = nil;
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
