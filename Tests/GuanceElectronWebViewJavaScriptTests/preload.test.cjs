'use strict'

const assert = require('node:assert/strict')
const { EventEmitter } = require('node:events')
const Module = require('node:module')
const test = require('node:test')

const preloadPath = '../../Sources/ElectronWebView/GuanceElectronRUM/preload.cjs'

function loadPreload() {
  delete require.cache[require.resolve(preloadPath)]
  return require(preloadPath)
}

test('preload exposes the fixed Web SDK bridge and enforces payload size', () => {
  const exposed = new Map()
  const ipcRenderer = new EventEmitter()
  const sent = []
  ipcRenderer.sendSync = () => ({
    enabled: true,
    allowedWebViewHosts: null,
    capabilities: '["records"]',
    privacyLevel: 'mask-user-input',
    maximumMessageBytes: 128,
  })
  ipcRenderer.send = (...args) => sent.push(args)

  const { install } = loadPreload()
  assert.equal(
    install({
      contextBridge: {
        exposeInMainWorld: (name, value) => exposed.set(name, value),
      },
      ipcRenderer,
    }),
    true,
  )

  const bridge = exposed.get('FTWebViewJavascriptBridge')
  assert.deepEqual([...exposed.keys()], ['FTWebViewJavascriptBridge'])
  assert.equal(bridge.getAllowedWebViewHosts(), null)
  assert.equal(bridge.getCapabilities(), '["records"]')
  assert.equal(bridge.getPrivacyLevel(), 'mask-user-input')

  bridge.sendEvent('{"type":"rum"}')
  assert.equal(sent.length, 1)
  assert.equal(sent[0][0], 'guance:electron-rum:message')
  assert.deepEqual(JSON.parse(sent[0][1]), [
    { handlerName: 'sendEvent', data: '{"type":"rum"}' },
  ])

  bridge.sendEvent('x'.repeat(256))
  assert.equal(sent.length, 1)
})

test('preload stays disabled for an unattached WebContents', () => {
  const exposed = []
  const { install } = loadPreload()
  const installed = install({
    contextBridge: {
      exposeInMainWorld: (...args) => exposed.push(args),
    },
    ipcRenderer: {
      sendSync: () => ({ enabled: false }),
    },
  })

  assert.equal(installed, false)
  assert.deepEqual(exposed, [])
})

test('preload skips bridge injection when renderer context isolation is disabled', () => {
  const exposed = []
  const warnings = []
  const originalType = process.type
  const originalContextIsolated = Object.getOwnPropertyDescriptor(
    process,
    'contextIsolated',
  )
  const originalWarn = console.warn
  process.type = 'renderer'
  Object.defineProperty(process, 'contextIsolated', {
    configurable: true,
    value: false,
  })
  console.warn = (message) => warnings.push(message)

  try {
    const { install } = loadPreload()
    const installed = install({
      contextBridge: {
        exposeInMainWorld: (...args) => exposed.push(args),
      },
      ipcRenderer: {
        sendSync: () => {
          throw new Error('disabled renderer must not request configuration')
        },
      },
    })

    assert.equal(installed, false)
    assert.deepEqual(exposed, [])
    assert.deepEqual(warnings, [
      '[Guance Electron RUM] skipped bridge injection: contextIsolation is disabled',
    ])
  } finally {
    console.warn = originalWarn
    if (originalType === undefined) {
      delete process.type
    } else {
      process.type = originalType
    }
    if (originalContextIsolated) {
      Object.defineProperty(process, 'contextIsolated', originalContextIsolated)
    } else {
      delete process.contextIsolated
    }
    delete require.cache[require.resolve(preloadPath)]
  }
})

test('preload installs its bridge automatically in an Electron renderer', () => {
  const exposed = new Map()
  const ipcRenderer = new EventEmitter()
  ipcRenderer.sendSync = () => ({
    enabled: true,
    allowedWebViewHosts: null,
    capabilities: '["records"]',
    privacyLevel: 'mask',
    maximumMessageBytes: 1024,
  })
  ipcRenderer.send = () => {}

  const originalType = process.type
  const originalContextIsolated = Object.getOwnPropertyDescriptor(
    process,
    'contextIsolated',
  )
  const originalLoad = Module._load
  process.type = 'renderer'
  Object.defineProperty(process, 'contextIsolated', {
    configurable: true,
    value: true,
  })
  Module._load = function loadElectronForPreload(request, parent, isMain) {
    if (request === 'electron') {
      return {
        contextBridge: {
          exposeInMainWorld: (name, value) => exposed.set(name, value),
        },
        ipcRenderer,
      }
    }
    return originalLoad.call(this, request, parent, isMain)
  }

  try {
    const { automaticallyInstalled } = loadPreload()
    assert.equal(automaticallyInstalled, true)
    assert.ok(exposed.get('FTWebViewJavascriptBridge'))
  } finally {
    Module._load = originalLoad
    if (originalType === undefined) {
      delete process.type
    } else {
      process.type = originalType
    }
    if (originalContextIsolated) {
      Object.defineProperty(process, 'contextIsolated', originalContextIsolated)
    } else {
      delete process.contextIsolated
    }
    delete require.cache[require.resolve(preloadPath)]
  }
})
