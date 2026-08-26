import assert from 'node:assert/strict'
import { once } from 'node:events'
import fs from 'node:fs'
import net from 'node:net'
import os from 'node:os'
import path from 'node:path'
import { test } from 'node:test'
import { CHANNELS } from '../src/main/bridge'
import {
  connectMixedModeWithElectron,
  MIXED_MODE_ENVIRONMENT,
} from '../src/main/mixed-internal'
import * as mixedPublic from '../src/main'
import { TestBrowserWindow, TestWebContents, testElectron } from './helpers'

const PROTOCOL_VERSION = 1

type Message = Record<string, unknown>

test('mixed public entry exposes no SDK configuration or lifecycle API', () => {
  assert.deepEqual(
    Object.keys(mixedPublic).sort(),
    ['GuanceElectronError', 'connectMixedMode'],
  )
  assert.equal('sdk' in mixedPublic, false)
  assert.equal('shutdown' in mixedPublic, false)
})

async function waitFor(predicate: () => boolean): Promise<void> {
  for (let index = 0; index < 100; index += 1) {
    if (predicate()) return
    await new Promise((resolve) => setTimeout(resolve, 10))
  }
  throw new Error('Timed out waiting for protocol state')
}

async function createProtocolServer(authenticationToken: string) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'guance-electron-'))
  const socketPath = path.join(directory, 'bridge.sock')
  const messages: Message[] = []
  let activeSocket: net.Socket | undefined
  let input = Buffer.alloc(0)

  const send = (message: Message): void => {
    if (activeSocket && !activeSocket.destroyed) {
      activeSocket.write(`${JSON.stringify(message)}\n`)
    }
  }
  const server = net.createServer((socket) => {
    activeSocket = socket
    socket.on('error', () => {
      // Client disposal may race with the final acknowledgement.
    })
    socket.on('data', (data) => {
      input = Buffer.concat([input, data])
      while (true) {
        const newline = input.indexOf(0x0a)
        if (newline < 0) return
        const line = input.subarray(0, newline)
        input = input.subarray(newline + 1)
        const message = JSON.parse(line.toString('utf8')) as Message
        messages.push(message)
        if (message.type === 'hello') {
          if (
            message.protocolVersion !== PROTOCOL_VERSION ||
            message.authenticationToken !== authenticationToken
          ) {
            socket.destroy()
            return
          }
          send({
            protocolVersion: PROTOCOL_VERSION,
            type: 'ready',
            connectionID: message.connectionID,
            configuration: {
              enableTraceWebView: true,
              allowedWebViewHosts: ['example.com'],
              maximumMessageBytes: 1024 * 1024,
              capabilities: '["records"]',
              privacyLevel: 'mask',
            },
          })
          continue
        }
        send({
          protocolVersion: PROTOCOL_VERSION,
          type: 'ack',
          connectionID: message.connectionID,
          sequence: message.sequence,
          requestID: message.requestID,
          ok: true,
          ...(message.type === 'register' ? { slotID: 7001 } : {}),
        })
      }
    })
  })
  server.listen(socketPath)
  await once(server, 'listening')

  return {
    socketPath,
    messages,
    sendCommand(webContentsID: number, command: string): void {
      const hello = messages.find((message) => message.type === 'hello')
      send({
        protocolVersion: PROTOCOL_VERSION,
        type: 'command',
        connectionID: hello?.connectionID,
        webContentsID,
        command,
      })
    },
    async close(): Promise<void> {
      activeSocket?.destroy()
      await new Promise<void>((resolve) => server.close(() => resolve()))
      fs.rmSync(directory, { recursive: true, force: true })
    },
  }
}

test('mixed mode reuses trusted window routing without loading the Native addon', async () => {
  const token = 'native-generated-token'
  const protocol = await createProtocolServer(token)
  try {
    const electron = testElectron()
    const controller = await connectMixedModeWithElectron(electron, {
      autoAttach: false,
      preloadPath: '/sdk/preload.js',
      environment: {
        [MIXED_MODE_ENVIRONMENT.socketPath]: protocol.socketPath,
        [MIXED_MODE_ENVIRONMENT.authenticationToken]: token,
        [MIXED_MODE_ENVIRONMENT.protocolVersion]: '1',
      },
    })
    assert.equal(controller.mode, 'mixed')
    assert.equal(controller.connected, true)

    const webContents = new TestWebContents(301)
    const window = new TestBrowserWindow(webContents)
    window.getNativeWindowHandle = (): Buffer => {
      throw new Error('Mixed Mode must not read an AppKit window handle')
    }
    electron.windows.push(window)
    const registration = controller.attachWindow(window)
    assert.deepEqual(webContents.session.preloads, ['/sdk/preload.js'])

    await waitFor(() => protocol.messages.some(
      (message) => message.type === 'register' && message.webContentsID === 301,
    ))
    const configurationEvent: {
      sender: TestWebContents
      returnValue?: unknown
    } = { sender: webContents }
    electron.ipcMain.emit(CHANNELS.configuration, configurationEvent)
    assert.equal(
      (configurationEvent.returnValue as { enabled: boolean }).enabled,
      true,
    )

    electron.ipcMain.emit(
      CHANNELS.message,
      { sender: webContents },
      '[{"handlerName":"sendEvent","data":"{}"}]',
    )
    await waitFor(() => protocol.messages.some(
      (message) => message.type === 'event' && message.webContentsID === 301,
    ))

    protocol.sendCommand(301, 'takeSubsequentFullSnapshot')
    await waitFor(() => webContents.executedScripts.length === 1)
    assert.equal(
      webContents.executedScripts[0],
      'window.DATAFLUX_RUM?.takeSubsequentFullSnapshot()',
    )

    registration.update({ visible: false })
    await waitFor(() => protocol.messages.some(
      (message) => message.type === 'update' && message.visible === false,
    ))
    controller.dispose()
    await waitFor(() => protocol.messages.some(
      (message) => message.type === 'close',
    ))
  } finally {
    await protocol.close()
  }
})

test('mixed mode requires Native-generated launch credentials', async () => {
  await assert.rejects(
    connectMixedModeWithElectron(testElectron(), { environment: {} }),
    /launch credentials are missing/,
  )
})
