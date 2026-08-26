import assert from 'node:assert/strict'
import { afterEach, beforeEach, test } from 'node:test'
import { CHANNELS, createBridgeApi } from '../src/main/bridge'
import { lifecycle } from '../src/main/lifecycle'
import { setNativeBindingForTesting } from '../src/main/native'
import { rum } from '../src/main/rum'
import { sdk } from '../src/main/sdk'
import { TestBrowserWindow, TestNativeBinding, TestWebContents, testElectron } from './helpers'

beforeEach(() => lifecycle.resetForTesting())
afterEach(() => {
  setNativeBindingForTesting(undefined)
  lifecycle.resetForTesting()
})

test('local bridge trusts the registered sender and updates visibility at host boundaries', async () => {
  const native = new TestNativeBinding()
  setNativeBindingForTesting(native)
  await sdk.initialize({ datakitUrl: 'http://127.0.0.1:9529' })
  await rum.configure({ appId: 'electron-app', enableTraceWebView: true })

  const electron = testElectron()
  const controller = await createBridgeApi(electron).start({ preloadPath: '/sdk/preload.js' })
  const webContents = new TestWebContents(11)
  const window = new TestBrowserWindow(webContents)
  electron.windows.push(window)
  electron.app.emit('browser-window-created', {}, window)

  assert.equal(native.registrations.length, 1)
  assert.equal(native.registrations[0].visible, true)
  assert.ok(Number(native.registrations[0].slotId) > 0)
  assert.deepEqual(webContents.session.preloads, ['/sdk/preload.js'])

  const configurationEvent: { sender: TestWebContents; returnValue?: unknown } = { sender: webContents }
  electron.ipcMain.emit(CHANNELS.configuration, configurationEvent)
  assert.equal((configurationEvent.returnValue as { enabled: boolean }).enabled, true)

  electron.ipcMain.emit(CHANNELS.message, { sender: webContents }, '[{"handlerName":"sendEvent","data":"{}"}]')
  assert.equal(native.messages.length, 1)

  webContents.navigate('https://not-example.invalid/')
  assert.equal(native.updates.at(-1)?.visible, false)
  electron.ipcMain.emit(CHANNELS.message, { sender: webContents }, 'blocked')
  assert.equal(native.messages.length, 1)

  await sdk.shutdown()
  assert.deepEqual(native.unregistered, [11])
  assert.equal(lifecycle.state, 'shutdown')
})

test('local bridge allows automatic collection to be disabled for selected windows', async () => {
  const native = new TestNativeBinding()
  setNativeBindingForTesting(native)
  await sdk.initialize({ datakitUrl: 'http://127.0.0.1:9529' })
  await rum.configure({ appId: 'electron-app', enableTraceWebView: true })

  const electron = testElectron()
  const api = createBridgeApi(electron)
  await api.start({ autoAttach: false, preloadPath: '/sdk/preload.js' })
  assert.deepEqual(electron.session.defaultSession.preloads, ['/sdk/preload.js'])

  const webContents = new TestWebContents(12)
  const window = new TestBrowserWindow(webContents)
  electron.windows.push(window)
  electron.app.emit('browser-window-created', {}, window)
  assert.equal(native.registrations.length, 0)

  api.attachWindow(window)
  assert.equal(native.registrations.length, 1)
  assert.deepEqual(webContents.session.preloads, ['/sdk/preload.js'])

  await sdk.shutdown()
  assert.deepEqual(native.unregistered, [12])
})
