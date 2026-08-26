const { app, BrowserWindow } = require('electron')
const useDelivery = process.argv.includes('--guance-fixture-delivery')
const {
  sdk,
  rum,
  bridge,
} = require(useDelivery
  ? '../../release/GuanceElectronMacOS/index.js'
  : '../../dist/src/main/index.js')

const autoQuit = process.env.GUANCE_FIXTURE_AUTO_QUIT === '1'
  || process.argv.includes('--guance-fixture-auto-quit')
const manualAttach = process.argv.includes('--guance-fixture-manual-attach')

app.whenReady().then(async () => {
  await sdk.initialize({
    datakitUrl: process.env.GUANCE_LOCAL_DATAKIT_URL
      || 'http://127.0.0.1:9529',
    autoSync: process.env.GUANCE_LOCAL_AUTO_SYNC === '1',
  })
  await rum.configure({
    appId: process.env.GUANCE_LOCAL_APP_ID
      || 'guance-electron-local-fixture',
    enableTraceUserView: false,
    enableTraceUserAction: false,
    enableTraceUserResource: false,
    enableTrackAppCrash: false,
    enableTrackAppFreeze: false,
    enableTrackAppANR: false,
    enableTraceWebView: true,
  })

  await bridge.start({ autoAttach: !manualAttach })
  const window = new BrowserWindow({
    width: 640,
    height: 480,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      ...(manualAttach ? { partition: 'persist:guance-manual-fixture' } : {}),
    },
  })
  if (manualAttach) bridge.attachWindow(window)
  await window.loadURL('data:text/html;charset=utf-8,' + encodeURIComponent(`
    <!doctype html>
    <meta charset="utf-8">
    <title>Guanceelectron Local Fixture</title>
    <h1>Guanceelectron Local mode</h1>
    <p>The Native SDK is owned by Electron main.</p>
  `))
  const preloadReady = await window.webContents.executeJavaScript(
    'Boolean(window.FTWebViewJavascriptBridge)',
  )
  if (!preloadReady) throw new Error('Guanceelectron preload bridge is unavailable')
  await window.webContents.executeJavaScript(`
    window.FTWebViewJavascriptBridge.sendEvent(JSON.stringify({
      name: 'rum',
      data: {
        measurement: 'view',
        tags: {
          app_id: 'guance-electron-local-fixture-web',
          view_id: 'local-fixture-view',
        },
        fields: { view_name: 'Guanceelectron Local fixture' },
        time: Date.now(),
      },
    }))
  `)
  console.log('Local Electron BrowserWindow fixture passed')
  if (autoQuit) window.close()
}).catch((error) => {
  console.error(error)
  app.exit(1)
})

app.on('window-all-closed', async () => {
  bridge.dispose()
  await sdk.shutdown()
  app.quit()
})
