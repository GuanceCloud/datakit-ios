import { EventEmitter } from 'node:events'
import type {
  Bounds,
  BrowserWindowLike,
  SessionLike,
  WebContentsLike,
} from '../src/main/types'
import type { NativeBinding } from '../src/main/native'

export class TestSession implements SessionLike {
  preloads: string[] = []
  getPreloads(): string[] { return [...this.preloads] }
  setPreloads(paths: string[]): void { this.preloads = [...paths] }
}

export class TestWebContents extends EventEmitter implements WebContentsLike {
  readonly session = new TestSession()
  executedScripts: string[] = []
  destroyed = false

  constructor(readonly id: number, private url = 'https://app.example.com/') {
    super()
  }

  getURL(): string { return this.url }
  isDestroyed(): boolean { return this.destroyed }
  executeJavaScript(script: string): Promise<void> {
    this.executedScripts.push(script)
    return Promise.resolve()
  }
  navigate(url: string): void {
    this.url = url
    this.emit('did-start-navigation', {}, url, false, true)
  }
}

export class TestBrowserWindow extends EventEmitter implements BrowserWindowLike {
  constructor(readonly webContents: TestWebContents) { super() }
  getNativeWindowHandle(): Buffer { return Buffer.alloc(8, 1) }
}

export class TestNativeBinding implements NativeBinding {
  readonly invocations: Array<{ method: string; payload: unknown }> = []
  readonly registrations: Array<Record<string, unknown>> = []
  readonly updates: Array<Record<string, unknown>> = []
  readonly messages: Array<{ id: number; value: string }> = []
  readonly unregistered: number[] = []
  commandHandler: ((webContentsId: number, command: string) => void) | null = null

  async invoke(method: string, payload: string): Promise<string> {
    this.invocations.push({ method, payload: JSON.parse(payload) })
    return method === 'trace.getHeaders' ? JSON.stringify({ traceparent: 'test' }) : '{}'
  }

  getElectronBridgeConfiguration() {
    return {
      enableTraceWebView: true,
      allowedWebViewHosts: ['example.com'],
      maximumMessageBytes: 1024 * 1024,
      capabilities: '[]',
      privacyLevel: 'mask',
    }
  }

  registerElectronWebContents(
    _handle: Buffer,
    webContentsId: number,
    slotId: number,
    visible: boolean,
    zIndex: number,
    bounds?: Bounds,
  ): boolean {
    this.registrations.push({ webContentsId, slotId, visible, zIndex, bounds })
    return true
  }

  updateElectronWebContents(
    _handle: Buffer,
    webContentsId: number,
    visible: boolean,
    zIndex: number,
    bounds?: Bounds,
  ): boolean {
    this.updates.push({ webContentsId, visible, zIndex, bounds })
    return true
  }

  receiveElectronWebContentsMessage(webContentsId: number, message: string): boolean {
    this.messages.push({ id: webContentsId, value: message })
    return true
  }

  unregisterElectronWebContents(webContentsId: number): void {
    this.unregistered.push(webContentsId)
  }

  setElectronCommandHandler(handler: ((webContentsId: number, command: string) => void) | null): void {
    this.commandHandler = handler
  }
}

export function testElectron() {
  const ipcMain = new EventEmitter()
  const app = new EventEmitter()
  const defaultSession = new TestSession()
  const windows: TestBrowserWindow[] = []
  return {
    ipcMain,
    app,
    session: { defaultSession },
    BrowserWindow: {
      getAllWindows: () => windows,
      fromWebContents: (webContents: WebContentsLike) =>
        windows.find((item) => item.webContents === webContents) || null,
    },
    windows,
  }
}
