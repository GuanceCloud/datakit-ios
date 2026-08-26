# Guance Electron Adapter

`@cloudcare/guance-electron-adapter` is the JavaScript-only Electron side of
macOS Mixed Mode. A Native macOS host initializes and owns the Guance SDK,
starts `FTElectronBridgeServer`, and launches Electron with generated socket
credentials.

```sh
npm install ./vendor/cloudcare-guance-electron-adapter-<version>.tgz
```

```js
const { app, BrowserWindow } = require('electron')
const { connectMixedMode } = require('@cloudcare/guance-electron-adapter')

app.whenReady().then(async () => {
  const bridge = await connectMixedMode()
  const window = new BrowserWindow({
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
    },
  })
  await window.loadURL('https://example.com')

  // bridge.dispose() disconnects Electron without stopping the Native SDK.
})
```

The Adapter installs the Guance preload and automatically registers current
and future `BrowserWindow` instances. Set `{ autoAttach: false }` and call
`bridge.attachWindow(window)` to select windows manually.

This package contains no Native Addon, dynamic library, resource bundle, SDK
configuration API, upload implementation, or Native SDK lifecycle API.
