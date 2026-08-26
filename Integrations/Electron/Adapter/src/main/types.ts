export interface Bounds {
  x: number
  y: number
  width: number
  height: number
}

export interface AttachOptions {
  visible?: boolean
  zIndex?: number
  bounds?: Bounds
  hostWindow?: BrowserWindowLike
}

export interface WebContentsLike {
  id: number
  session?: SessionLike
  getURL?(): string
  isDestroyed?(): boolean
  executeJavaScript?(script: string): Promise<unknown> | unknown
  on(event: string, listener: (...args: any[]) => void): this
  once(event: string, listener: (...args: any[]) => void): this
  removeListener(event: string, listener: (...args: any[]) => void): this
}

export interface BrowserWindowLike {
  webContents: WebContentsLike
  getNativeWindowHandle?(): Buffer
  on(event: string, listener: (...args: any[]) => void): this
  once(event: string, listener: (...args: any[]) => void): this
  removeListener(event: string, listener: (...args: any[]) => void): this
}

export interface SessionLike {
  getPreloads(): string[]
  setPreloads(paths: string[]): void
}

export interface WebContentsRegistration {
  update(options: Pick<AttachOptions, 'visible' | 'zIndex' | 'bounds'>): void
  dispose(): void
}

export interface BridgeController {
  readonly mode: 'full' | 'mixed'
  readonly connected: boolean
  attachWindow(window: BrowserWindowLike, options?: AttachOptions): WebContentsRegistration
  attachWebContents(webContents: WebContentsLike, options?: AttachOptions): WebContentsRegistration
  installSessionPreload(session: SessionLike): void
  dispose(): void
}

export interface BridgeConfiguration {
  enableTraceWebView: boolean
  allowedWebViewHosts: string[] | null
  maximumMessageBytes: number
  capabilities?: string
  privacyLevel?: string
  [key: string]: unknown
}

export interface BridgeStartOptions {
  autoAttach?: boolean
}

export interface MixedModeConnectOptions extends BridgeStartOptions {
  connectTimeoutMs?: number
}

export interface MixedModeBridge {
  readonly connected: boolean
  attachWindow(
    window: BrowserWindowLike,
    options?: AttachOptions,
  ): WebContentsRegistration
  dispose(): void
}
