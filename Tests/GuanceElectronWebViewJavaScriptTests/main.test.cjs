'use strict'

const assert = require('node:assert/strict')
const { EventEmitter } = require('node:events')
const test = require('node:test')

const {
  createElectronRUM,
} = require('../../Sources/ElectronWebView/GuanceElectronRUM/main.cjs')

class FakeIPCMain extends EventEmitter {}

class FakeWebContents extends EventEmitter {
  constructor(id, session = null) {
    super()
    this.id = id
    this.session = session
    this.sent = []
    this.executedScripts = []
    this.destroyed = false
  }

  send(...args) {
    this.sent.push(args)
  }

  executeJavaScript(script) {
    this.executedScripts.push(script)
    return Promise.resolve()
  }

  isDestroyed() {
    return this.destroyed
  }
}

class FakeBrowserWindow extends EventEmitter {
  constructor(id, session = null) {
    super()
    this.webContents = new FakeWebContents(id, session)
    this.handle = Buffer.alloc(8, id)
    this.browserViews = []
  }

  getNativeWindowHandle() {
    return this.handle
  }

  getBrowserViews() {
    return [...this.browserViews]
  }

  addBrowserView(browserView) {
    if (!this.browserViews.includes(browserView)) {
      this.browserViews.push(browserView)
    }
  }

  setBrowserView(browserView) {
    this.browserViews = browserView ? [browserView] : []
  }

  removeBrowserView(browserView) {
    this.browserViews = this.browserViews.filter((view) => view !== browserView)
  }

  setTopBrowserView(browserView) {
    this.removeBrowserView(browserView)
    this.browserViews.push(browserView)
  }
}

class FakeBrowserView {
  constructor(id, bounds, session = null) {
    this.webContents = new FakeWebContents(id, session)
    this.bounds = bounds
  }

  getBounds() {
    return { ...this.bounds }
  }

  setBounds(bounds) {
    this.bounds = { ...bounds }
  }
}

class FakeApp extends EventEmitter {}

class FakeSession {
  constructor(preloads = []) {
    this.preloads = [...preloads]
    this.setCalls = []
  }

  getPreloads() {
    return [...this.preloads]
  }

  setPreloads(preloads) {
    this.preloads = [...preloads]
    this.setCalls.push([...preloads])
  }
}

function makeNativeBridge() {
  const calls = {
    commandHandlers: [],
    register: [],
    update: [],
    receive: [],
    unregister: [],
  }
  return {
    calls,
    getElectronBridgeConfiguration: () => JSON.stringify({
      enableTraceWebView: true,
      allowedWebViewHosts: null,
      capabilities: '["records"]',
      privacyLevel: 'mask',
      maximumMessageBytes: 1024,
    }),
    setElectronCommandHandler: (handler) => {
      calls.commandHandlers.push(handler)
    },
    registerElectronWebContents: (...args) => {
      calls.register.push(args)
      return true
    },
    updateElectronWebContents: (...args) => {
      calls.update.push(args)
      return true
    },
    receiveElectronWebContentsMessage: (...args) => {
      calls.receive.push(args)
      return true
    },
    unregisterElectronWebContents: (...args) => {
      calls.unregister.push(args)
    },
  }
}

test('attach registers trusted sender and forwards bridge messages', () => {
  const ipcMain = new FakeIPCMain()
  const integration = createElectronRUM({ ipcMain })
  const browserWindow = new FakeBrowserWindow(42)
  const nativeBridge = makeNativeBridge()
  const controller = integration.attach(browserWindow, nativeBridge, {
    slotID: 9001,
  })

  assert.equal(controller.webContentsID, 42)
  assert.equal(controller.slotID, 9001)
  assert.deepEqual(nativeBridge.calls.register[0], [
    browserWindow.handle,
    42,
    9001,
    true,
    0,
    null,
  ])

  const configurationEvent = { sender: browserWindow.webContents }
  ipcMain.emit('guance:electron-rum:get-configuration', configurationEvent)
  assert.deepEqual(configurationEvent.returnValue, {
    enabled: true,
    enableTraceWebView: true,
    allowedWebViewHosts: null,
    capabilities: '["records"]',
    privacyLevel: 'mask',
    maximumMessageBytes: 1024,
  })

  ipcMain.emit(
    'guance:electron-rum:message',
    { sender: browserWindow.webContents },
    '[{"handlerName":"sendEvent","data":"{}"}]',
  )
  assert.deepEqual(nativeBridge.calls.receive, [
    [42, '[{"handlerName":"sendEvent","data":"{}"}]'],
  ])

  integration.dispose()
})

test('unknown IPC sender cannot select a registration or slot', () => {
  const ipcMain = new FakeIPCMain()
  const integration = createElectronRUM({ ipcMain })
  const browserWindow = new FakeBrowserWindow(10)
  const nativeBridge = makeNativeBridge()
  integration.attach(browserWindow, nativeBridge)

  const unknown = new FakeWebContents(11)
  const configurationEvent = { sender: unknown }
  ipcMain.emit('guance:electron-rum:get-configuration', configurationEvent)
  assert.deepEqual(configurationEvent.returnValue, { enabled: false })

  ipcMain.emit(
    'guance:electron-rum:message',
    { sender: unknown },
    'untrusted',
  )
  assert.equal(nativeBridge.calls.receive.length, 0)

  integration.dispose()
})

test('controller updates visibility, executes fixed replay command, and detaches once', () => {
  const ipcMain = new FakeIPCMain()
  const integration = createElectronRUM({ ipcMain })
  const browserWindow = new FakeBrowserWindow(7)
  const nativeBridge = makeNativeBridge()
  const controller = integration.attach(browserWindow, nativeBridge, {
    slotID: 77,
  })

  assert.equal(controller.update({ visible: false, zIndex: 2 }), true)
  assert.deepEqual(nativeBridge.calls.update.at(-1), [
    browserWindow.handle,
    7,
    false,
    2,
    null,
  ])

  assert.equal(
    controller.handleNativeCommand(
      'electron-command:7:takeSubsequentFullSnapshot',
    ),
    true,
  )
  assert.deepEqual(browserWindow.webContents.executedScripts, [
    'window.DATAFLUX_RUM?.takeSubsequentFullSnapshot()',
  ])
  assert.equal(
    controller.handleNativeCommand(
      'electron-command:8:takeSubsequentFullSnapshot',
    ),
    false,
  )
  assert.equal(
    controller.handleNativeCommand('takeSubsequentFullSnapshot;alert(1)'),
    false,
  )
  assert.deepEqual(browserWindow.webContents.executedScripts, [
    'window.DATAFLUX_RUM?.takeSubsequentFullSnapshot()',
  ])

  browserWindow.emit('closed')
  controller.detach()
  assert.deepEqual(nativeBridge.calls.unregister, [[7]])

  integration.dispose()
})

test('attach fails closed when native SDK registration is unavailable', () => {
  const ipcMain = new FakeIPCMain()
  const integration = createElectronRUM({ ipcMain })
  const browserWindow = new FakeBrowserWindow(3)
  const nativeBridge = makeNativeBridge()
  nativeBridge.registerElectronWebContents = () => false

  assert.throws(
    () => integration.attach(browserWindow, nativeBridge),
    /initialize native RUM and Electron WebView support/,
  )
  integration.dispose()
})

test('initialized client attaches multiple windows with independent slots', () => {
  const ipcMain = new FakeIPCMain()
  const integration = createElectronRUM({ ipcMain })
  const nativeBridge = makeNativeBridge()
  const client = integration.initialize({ nativeBridge })
  const mainWindow = new FakeBrowserWindow(101)
  const detailWindow = new FakeBrowserWindow(102)

  const mainController = client.attachWindow(mainWindow)
  const detailController = client.attachWindow(detailWindow)

  assert.notEqual(mainController.slotID, detailController.slotID)
  assert.deepEqual(
    nativeBridge.calls.register.map((call) => [call[1], call[2]]),
    [
      [101, mainController.slotID],
      [102, detailController.slotID],
    ],
  )

  assert.equal(
    client.dispatchNativeCommand(102, 'takeSubsequentFullSnapshot'),
    true,
  )
  assert.deepEqual(detailWindow.webContents.executedScripts, [
    'window.DATAFLUX_RUM?.takeSubsequentFullSnapshot()',
  ])
  assert.equal(
    client.dispatchNativeCommand(999, 'takeSubsequentFullSnapshot'),
    false,
  )

  mainController.detach()
  assert.deepEqual(nativeBridge.calls.unregister, [[101]])
  assert.equal(
    client.dispatchNativeCommand(101, 'takeSubsequentFullSnapshot'),
    false,
  )
  assert.equal(
    client.dispatchNativeCommand(102, 'takeSubsequentFullSnapshot'),
    true,
  )

  client.dispose()
  assert.deepEqual(nativeBridge.calls.unregister, [[101], [102]])
  integration.dispose()
})

test('native enableTraceWebView auto-attaches existing and future Electron 22 windows', () => {
  const ipcMain = new FakeIPCMain()
  const app = new FakeApp()
  const existingWindow = new FakeBrowserWindow(301)
  const BrowserWindow = {
    getAllWindows: () => [existingWindow],
  }
  const integration = createElectronRUM({ ipcMain, app, BrowserWindow })
  const nativeBridge = makeNativeBridge()
  const client = integration.initialize({ nativeBridge })

  assert.equal(client.autoAttachEnabled, true)
  assert.equal(client.configuration.enableTraceWebView, true)
  assert.equal(nativeBridge.calls.register.length, 1)

  const futureWindow = new FakeBrowserWindow(302)
  app.emit('browser-window-created', {}, futureWindow)
  assert.deepEqual(
    nativeBridge.calls.register.map((call) => call[1]),
    [301, 302],
  )

  const sameController = client.attachWindow(futureWindow)
  assert.equal(sameController.webContentsID, 302)
  assert.equal(nativeBridge.calls.register.length, 2)

  client.dispose()
  assert.equal(app.listenerCount('browser-window-created'), 0)
  integration.dispose()
})

test('bootstrap automatically installs its preload and tracks BrowserView switches', () => {
  const ipcMain = new FakeIPCMain()
  const app = new FakeApp()
  const defaultSession = new FakeSession(['/app/business-preload.cjs'])
  const browserWindow = new FakeBrowserWindow(340, defaultSession)
  const BrowserWindow = { getAllWindows: () => [browserWindow] }
  const integration = createElectronRUM({
    ipcMain,
    app,
    BrowserWindow,
    session: { defaultSession },
  })
  const nativeBridge = makeNativeBridge()
  const client = integration.bootstrap({ nativeBridge })
  const firstView = new FakeBrowserView(341, {
    x: 0,
    y: 0,
    width: 400,
    height: 600,
  }, defaultSession)
  const secondView = new FakeBrowserView(342, {
    x: 400,
    y: 0,
    width: 400,
    height: 600,
  }, defaultSession)

  assert.equal(client.autoAttachEnabled, true)
  assert.equal(defaultSession.setCalls.length, 1)
  assert.equal(defaultSession.preloads.length, 2)
  assert.match(
    defaultSession.preloads[1],
    /ElectronWebView\/GuanceElectronRUM\/preload\.cjs$/,
  )

  browserWindow.setBrowserView(firstView)
  const firstRegister = nativeBridge.calls.register.at(-1)
  const firstSlotID = firstRegister[2]
  assert.deepEqual(firstRegister.slice(1), [
    341,
    firstSlotID,
    true,
    0,
    { x: 0, y: 0, width: 400, height: 600 },
  ])

  browserWindow.setBrowserView(secondView)
  const secondRegister = nativeBridge.calls.register.at(-1)
  const secondSlotID = secondRegister[2]
  assert.notEqual(firstSlotID, secondSlotID)
  assert.deepEqual(nativeBridge.calls.update.at(-1).slice(1), [
    341,
    false,
    0,
    { x: 0, y: 0, width: 400, height: 600 },
  ])
  assert.deepEqual(secondRegister.slice(1), [
    342,
    secondSlotID,
    true,
    0,
    { x: 400, y: 0, width: 400, height: 600 },
  ])

  browserWindow.setBrowserView(firstView)
  assert.equal(
    nativeBridge.calls.register.filter((call) => call[1] === 341).length,
    1,
  )
  assert.deepEqual(nativeBridge.calls.update.at(-1).slice(1), [
    342,
    false,
    0,
    { x: 400, y: 0, width: 400, height: 600 },
  ])
  assert.deepEqual(nativeBridge.calls.update.at(-2).slice(1), [
    341,
    true,
    0,
    { x: 0, y: 0, width: 400, height: 600 },
  ])

  firstView.setBounds({ x: 20, y: 10, width: 760, height: 560 })
  assert.deepEqual(nativeBridge.calls.update.at(-1).slice(1), [
    341,
    true,
    0,
    { x: 20, y: 10, width: 760, height: 560 },
  ])

  client.dispose()
  integration.dispose()
})

test('bootstrap automatically routes fixed bridge replay commands', () => {
  const ipcMain = new FakeIPCMain()
  const app = new FakeApp()
  const browserWindow = new FakeBrowserWindow(350)
  const BrowserWindow = { getAllWindows: () => [browserWindow] }
  const integration = createElectronRUM({ ipcMain, app, BrowserWindow })
  const nativeBridge = makeNativeBridge()

  const client = integration.bootstrap({ nativeBridge })
  assert.equal(nativeBridge.calls.commandHandlers.length, 1)

  nativeBridge.calls.commandHandlers[0](350, 'takeSubsequentFullSnapshot')
  assert.deepEqual(browserWindow.webContents.executedScripts, [
    'window.DATAFLUX_RUM?.takeSubsequentFullSnapshot()',
  ])

  client.dispose()
  assert.equal(nativeBridge.calls.commandHandlers.at(-1), null)
  integration.dispose()
})

test('native disabled WebView collection skips automatic mode but keeps explicit attachWindow', () => {
  const ipcMain = new FakeIPCMain()
  const app = new FakeApp()
  const existingWindow = new FakeBrowserWindow(311)
  const BrowserWindow = { getAllWindows: () => [existingWindow] }
  const integration = createElectronRUM({ ipcMain, app, BrowserWindow })
  const nativeBridge = makeNativeBridge()
  nativeBridge.getElectronBridgeConfiguration = () => ({
    enableTraceWebView: false,
    allowedWebViewHosts: null,
  })

  const client = integration.initialize({ nativeBridge })
  assert.equal(client.autoAttachEnabled, false)
  assert.equal(nativeBridge.calls.register.length, 0)

  const controller = client.attachWindow(existingWindow)
  assert.equal(controller.webContentsID, 311)
  assert.equal(nativeBridge.calls.register.length, 1)

  client.dispose()
  integration.dispose()
})

test('attachWebContents registers Electron 22 BrowserViews with independent bounds', () => {
  const ipcMain = new FakeIPCMain()
  const integration = createElectronRUM({ ipcMain })
  const nativeBridge = makeNativeBridge()
  const client = integration.initialize({ nativeBridge })
  const browserWindow = new FakeBrowserWindow(320)
  const firstView = new FakeBrowserView(321, {
    x: 0,
    y: 0,
    width: 400,
    height: 600,
  })
  const secondView = new FakeBrowserView(322, {
    x: 400,
    y: 0,
    width: 400,
    height: 600,
  })

  const first = client.attachWebContents(browserWindow, firstView, { zIndex: 0 })
  const second = client.attachWebContents(browserWindow, secondView, { zIndex: 1 })

  assert.notEqual(first.slotID, second.slotID)
  assert.deepEqual(nativeBridge.calls.register[0].slice(1), [
    321,
    first.slotID,
    true,
    0,
    { x: 0, y: 0, width: 400, height: 600 },
  ])
  assert.deepEqual(nativeBridge.calls.register[1].slice(1), [
    322,
    second.slotID,
    true,
    1,
    { x: 400, y: 0, width: 400, height: 600 },
  ])

  secondView.bounds = { x: 300, y: 20, width: 500, height: 560 }
  assert.equal(second.update({ visible: true, zIndex: 2 }), true)
  assert.deepEqual(nativeBridge.calls.update.at(-1).slice(1), [
    322,
    true,
    2,
    { x: 300, y: 20, width: 500, height: 560 },
  ])

  client.dispose()
  integration.dispose()
})

test('native allowed hosts disable forwarding and slot visibility for unmatched navigation', () => {
  const ipcMain = new FakeIPCMain()
  const integration = createElectronRUM({ ipcMain })
  const nativeBridge = makeNativeBridge()
  nativeBridge.getElectronBridgeConfiguration = () => ({
    enableTraceWebView: true,
    allowedWebViewHosts: ['example.com'],
  })
  const client = integration.initialize({ nativeBridge })
  const browserWindow = new FakeBrowserWindow(330)
  const controller = client.attachWindow(browserWindow)

  assert.deepEqual(nativeBridge.calls.register.at(-1).slice(1), [
    330,
    controller.slotID,
    false,
    0,
    null,
  ])

  browserWindow.webContents.emit(
    'did-start-navigation',
    {},
    'https://sub.example.com/dashboard',
    false,
    true,
  )
  assert.deepEqual(nativeBridge.calls.update.at(-1).slice(1), [
    330,
    true,
    0,
    null,
  ])

  const allowedConfiguration = { sender: browserWindow.webContents }
  ipcMain.emit('guance:electron-rum:get-configuration', allowedConfiguration)
  assert.equal(allowedConfiguration.returnValue.enabled, true)
  assert.deepEqual(
    allowedConfiguration.returnValue.allowedWebViewHosts,
    ['example.com'],
  )

  browserWindow.webContents.emit(
    'did-start-navigation',
    {},
    'https://blocked.test/dashboard',
    false,
    true,
  )
  assert.deepEqual(nativeBridge.calls.update.at(-1).slice(1), [
    330,
    false,
    0,
    null,
  ])

  const blockedConfiguration = { sender: browserWindow.webContents }
  ipcMain.emit('guance:electron-rum:get-configuration', blockedConfiguration)
  assert.deepEqual(blockedConfiguration.returnValue, { enabled: false })

  ipcMain.emit(
    'guance:electron-rum:message',
    { sender: browserWindow.webContents },
    '[{"handlerName":"sendEvent","data":"{}"}]',
  )
  assert.equal(nativeBridge.calls.receive.length, 0)

  controller.detach()
  integration.dispose()
})

test('client disposal does not detach legacy registrations', () => {
  const ipcMain = new FakeIPCMain()
  const integration = createElectronRUM({ ipcMain })
  const nativeBridge = makeNativeBridge()
  const legacyWindow = new FakeBrowserWindow(201)
  const clientWindow = new FakeBrowserWindow(202)

  integration.attach(legacyWindow, nativeBridge, { slotID: 1201 })
  const client = integration.initialize({ nativeBridge })
  client.attachWindow(clientWindow, { slotID: 1202 })

  client.dispose()
  assert.deepEqual(nativeBridge.calls.unregister, [[202]])

  const configurationEvent = { sender: legacyWindow.webContents }
  ipcMain.emit('guance:electron-rum:get-configuration', configurationEvent)
  assert.equal(configurationEvent.returnValue.enabled, true)
  assert.equal(
    integration.dispatchNativeCommand(201, 'takeSubsequentFullSnapshot'),
    true,
  )

  assert.throws(
    () => client.attachWindow(new FakeBrowserWindow(203)),
    /client is disposed/,
  )
  integration.dispose()
  assert.deepEqual(nativeBridge.calls.unregister, [[202], [201]])
})

test('initialize validates the native bridge once', () => {
  const integration = createElectronRUM({ ipcMain: new FakeIPCMain() })

  assert.throws(
    () => integration.initialize({ nativeBridge: {} }),
    /Native bridge is missing getElectronBridgeConfiguration/,
  )
  assert.throws(
    () => integration.initialize(),
    /initialized native bridge/,
  )
  integration.dispose()
})
