# Guance Electron macOS Full Mode

`@cloudcare/guance-electron-macos` adapts the Guance macOS Native SDK to an
Electron application whose Main Process owns SDK initialization, Native data
persistence, upload, and the WebView bridge.

The package embeds the matching `@cloudcare/guance-electron-adapter` runtime so
Full Mode customers install only this package.

```sh
npm install ./vendor/cloudcare-guance-electron-macos-<version>.tgz
```

```js
const { app, BrowserWindow } = require('electron')
const {
  sdk,
  rum,
  logger,
  trace,
  sessionReplay,
  bridge,
} = require('@cloudcare/guance-electron-macos')

app.whenReady().then(async () => {
  await sdk.initialize({
    datakitUrl: 'http://127.0.0.1:9529',
    service: 'electron-main',
    autoSync: true,
  })
  await rum.configure({
    appId: 'YOUR_RUM_APPLICATION_ID',
    enableTraceWebView: true,
    enableTraceUserView: true,
  })
  await logger.configure({ enableCustomLog: true })
  await trace.configure({ traceType: 'traceparent' })
  await sessionReplay.configure({ sampleRate: 100 })
  await bridge.start()

  const window = new BrowserWindow({
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
    },
  })
  await window.loadURL('https://example.com')
})
```

`bridge.start()` automatically attaches current and future windows. Set
`{ autoAttach: false }` and call `bridge.attachWindow(window)` to select windows
manually.

Keep the package's complete `native/` directory outside ASAR. Include
`native/guance_electron.node` and
`native/libGuanceElectronNative.dylib` in the application's existing nested
binary signing process. Production Developer ID signing, hardened runtime,
notarization, and stapling remain part of the application's normal release
pipeline.
