import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import test from 'node:test'
import vm from 'node:vm'
import { CHANNELS } from '../src/main/bridge'
import { install } from '../src/preload'

test('preload exposes only the Web SDK bridge and enforces the configured byte limit', () => {
  let exposedName: string | undefined
  let exposedValue: Record<string, (...args: any[]) => any> | undefined
  const sent: Array<{ channel: string; value: unknown }> = []
  const electron = {
    contextBridge: {
      exposeInMainWorld(name: string, value: unknown): void {
        exposedName = name
        exposedValue = value as Record<string, (...args: any[]) => any>
      },
    },
    ipcRenderer: {
      sendSync(channel: string): unknown {
        assert.equal(channel, CHANNELS.configuration)
        return {
          enabled: true,
          allowedWebViewHosts: ['example.com'],
          capabilities: '["rum","sessionReplay"]',
          privacyLevel: 'mask',
          maximumMessageBytes: 128,
        }
      },
      send(channel: string, value: unknown): void {
        sent.push({ channel, value })
      },
    },
  }

  assert.equal(install(electron), true)
  assert.equal(exposedName, 'FTWebViewJavascriptBridge')
  assert.deepEqual(Object.keys(exposedValue!).sort(), [
    'getAllowedWebViewHosts',
    'getCapabilities',
    'getPrivacyLevel',
    'sendEvent',
  ])
  assert.equal(exposedValue!.getAllowedWebViewHosts(), '["example.com"]')

  exposedValue!.sendEvent('{"name":"rum"}')
  assert.equal(sent.length, 1)
  assert.equal(sent[0].channel, CHANNELS.message)
  exposedValue!.sendEvent('x'.repeat(512))
  exposedValue!.sendEvent({ unsafe: true })
  assert.equal(sent.length, 1)
})

test('runtime preload executes in an Electron sandbox without CommonJS globals', () => {
  let exposedName: string | undefined
  const electron = {
    contextBridge: {
      exposeInMainWorld(name: string): void { exposedName = name },
    },
    ipcRenderer: {
      sendSync(): unknown {
        return { enabled: true, maximumMessageBytes: 1024 }
      },
      send(): void {},
    },
  }
  const source = fs.readFileSync(
    path.resolve(__dirname, '..', 'preload.js'),
    'utf8',
  )

  vm.runInNewContext(source, {
    process: { type: 'renderer' },
    require(id: string): unknown {
      assert.equal(id, 'electron')
      return electron
    },
    TextEncoder,
  })

  assert.equal(exposedName, 'FTWebViewJavascriptBridge')
})
