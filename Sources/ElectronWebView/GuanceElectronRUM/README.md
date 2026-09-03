# macOS Native + Electron Quick Start

Use this guide when a macOS Native application embeds Electron pages.

Electron Main, IPC, and preload integration are provided by the published
`@cloudcare/electron-native-adapter` npm package. This directory only keeps the
precompiled universal macOS `GuanceElectronBridge.node` used by the package's
`embedded` mode. Do not copy JavaScript integration files from this repository
into an Electron application.

The bridge supports `arm64` and `x86_64`. It is a Main-process adapter, not a
second Native SDK: it calls the already-loaded `FTElectronWebViewHandler` in the
same process and never initializes Guance SDK products.

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
Replay before Electron navigation.

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

- `enableTraceWebView = YES`: allows automatic BrowserWindow attachment.
- `allowWebViewHost = nil` or `@[]`: collects all H5 hosts.
- `allowWebViewHost = @[@"example.com"]`: collects `example.com` and its
  subdomains.

## 3. Install the Electron adapter

Install the JavaScript adapter from npm:

```bash
npm install @cloudcare/electron-native-adapter
```

The npm package intentionally contains no `.node` binary. Copy
`GuanceElectronBridge.node` into the Electron application's unpacked resources
using its existing macOS Native SDK packaging workflow.

## 4. Configure Electron Main and preload

Call `bootstrap()` before the first collected page calls `loadURL()` or
`loadFile()`:

```js
const path = require('node:path')
const electron = require('electron')
const {
  bootstrap,
} = require('@cloudcare/electron-native-adapter')

const nativeBridge = require(path.join(
  process.resourcesPath,
  'GuanceElectronBridge.node',
))

electron.app.whenReady().then(async () => {
  const client = await bootstrap({
    electron,
    native: {
      mode: 'embedded',
      bridge: nativeBridge,
    },
    autoAttach: true,
    onError(error) {
      console.error('[Guance Electron RUM]', error)
    },
  })

  const mainWindow = new electron.BrowserWindow({
    webPreferences: {
      contextIsolation: true,
      preload: require.resolve(
        '@cloudcare/electron-native-adapter/preload/standalone',
      ),
    },
  })
  await mainWindow.loadURL(mainURL)

  electron.app.once('before-quit', () => {
    void client.stop()
  })
})
```

If the application already has a preload, compose the bridge there instead:

```js
const {
  installElectronRumPreload,
} = require('@cloudcare/electron-native-adapter/preload/install')

installElectronRumPreload()
```

Every collected BrowserWindow or BrowserView must keep
`contextIsolation: true`. A renderer without the shared preload does not expose
`window.FTWebViewJavascriptBridge` and cannot forward Web RUM or Web Session
Replay.

To attach selected windows explicitly:

```js
const client = await bootstrap({
  electron,
  native: { mode: 'embedded', bridge: nativeBridge },
  autoAttach: false,
})

const detailWindow = new electron.BrowserWindow(detailOptions)
const detach = client.attachWindow(detailWindow)
await detailWindow.loadURL(detailURL)

// Later:
detach()
```

BrowserView/WebContents layout is explicit in the shared lifecycle:

```js
client.attachWindow(browserView, {
  browserWindow,
  visible: true,
  zIndex: 0,
  bounds: browserView.getBounds(),
})

client.updateWindow(browserView, {
  visible: true,
  bounds: browserView.getBounds(),
})
```

## 5. Initialize the Web SDK

Initialize the Guance Web SDK normally in every H5 page, then start Web Session
Replay:

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

## 6. Package and verify

For a release build, keep `GuanceElectronBridge.node` outside ASAR and sign it
with the same signing workflow as the application. Rebuild it only when its
Node-API surface, required architecture, or Electron compatibility changes.

Verify the integration:

1. Open a collected page and confirm
   `Boolean(window.FTWebViewJavascriptBridge)` is `true`.
2. Trigger an H5 action or request. Native and H5 RUM events should share the
   uploaded `session_id`.
3. Trigger Native and H5 interactions. Session Replay should contain both.
