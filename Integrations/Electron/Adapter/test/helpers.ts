import { EventEmitter } from 'node:events'
import type {
  Bounds,
  BrowserWindowLike,
  SessionLike,
  WebContentsLike,
} from '../src/main/types'

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
