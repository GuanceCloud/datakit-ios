import fs from 'node:fs'
import path from 'node:path'
import { isAllowedHost } from './bridge-configuration'
import { GuanceElectronError } from './errors'
import type { BridgeTransport, TransportRegistration } from './transport'
import type {
  AttachOptions,
  Bounds,
  BridgeController,
  BridgeStartOptions,
  BrowserWindowLike,
  SessionLike,
  WebContentsLike,
  WebContentsRegistration,
} from './types'
import { normalizeBounds } from './validation'

export const CHANNELS = Object.freeze({
  configuration: 'guance:electron:get-configuration',
  message: 'guance:electron:web-message',
})

const FULL_SNAPSHOT_COMMAND = 'takeSubsequentFullSnapshot'
const FULL_SNAPSHOT_SCRIPT = 'window.DATAFLUX_RUM?.takeSubsequentFullSnapshot()'

export interface IpcMainLike {
  on(channel: string, listener: (...args: any[]) => void): void
  removeListener(channel: string, listener: (...args: any[]) => void): void
}

export interface AppLike {
  on(event: string, listener: (...args: any[]) => void): void
  removeListener(event: string, listener: (...args: any[]) => void): void
}

export interface ElectronLike {
  ipcMain: IpcMainLike
  app?: AppLike
  BrowserWindow?: {
    getAllWindows?(): BrowserWindowLike[]
    fromWebContents?(webContents: WebContentsLike): BrowserWindowLike | null
  }
  session?: { defaultSession?: SessionLike }
}

export type InternalBridgeStartOptions = BridgeStartOptions & {
  preloadPath?: string
}

interface RegistrationState {
  webContents: WebContentsLike
  hostWindow?: BrowserWindowLike
  visible: boolean
  zIndex: number
  bounds?: Bounds
  hostAllowed: boolean
  disposed: boolean
  onNavigation: (...args: any[]) => void
  onDestroyed: () => void
  onResize?: () => void
}

function defaultPreloadPath(): string {
  const preload = path.join(__dirname, '..', '..', 'preload.js')
  if (!fs.existsSync(preload)) {
    throw new GuanceElectronError(
      'NATIVE_UNAVAILABLE',
      `Guance Electron preload is missing: ${preload}`,
    )
  }
  return preload
}

function assertWebContents(value: WebContentsLike): void {
  if (!value || !Number.isSafeInteger(value.id) || typeof value.on !== 'function') {
    throw new GuanceElectronError(
      'INVALID_ARGUMENT',
      'A valid Electron WebContents is required',
    )
  }
}

function byteLength(value: string): number {
  return Buffer.byteLength(value, 'utf8')
}

export class Controller implements BridgeController {
  readonly mode
  private readonly configuration
  private readonly registrations = new Map<number, RegistrationState>()
  private disposed = false
  private autoAttachListener?: (...args: any[]) => void

  private readonly onConfiguration = (
    event: { sender?: WebContentsLike; returnValue?: unknown },
  ): void => {
    const registration = this.registrationForSender(event.sender)
    event.returnValue = registration?.hostAllowed && registration.visible
      ? { enabled: true, ...this.configuration }
      : { enabled: false }
  }

  private readonly onRendererMessage = (
    event: { sender?: WebContentsLike },
    messageQueue: unknown,
  ): void => {
    const registration = this.registrationForSender(event.sender)
    if (
      !registration ||
      !registration.hostAllowed ||
      !registration.visible ||
      typeof messageQueue !== 'string' ||
      byteLength(messageQueue) > this.configuration.maximumMessageBytes
    ) return

    this.transport.sendEvent(registration.webContents.id, messageQueue)
  }

  constructor(
    private readonly electron: ElectronLike,
    private readonly transport: BridgeTransport,
    private readonly preloadPath: string,
    autoAttach: boolean,
  ) {
    this.mode = transport.mode
    this.configuration = transport.configuration
    electron.ipcMain.on(CHANNELS.configuration, this.onConfiguration)
    electron.ipcMain.on(CHANNELS.message, this.onRendererMessage)

    transport.setCommandHandler((id, command) => this.dispatchCommand(id, command))
    const defaultSession = this.electron.session?.defaultSession
    if (defaultSession) this.installSessionPreload(defaultSession)
    if (autoAttach) this.installAutoAttach()
    if (this.mode === 'full') {
    }
  }

  get connected(): boolean { return this.transport.connected }

  attachWindow(
    window: BrowserWindowLike,
    options: AttachOptions = {},
  ): WebContentsRegistration {
    if (!window?.webContents) {
      throw new GuanceElectronError(
        'INVALID_ARGUMENT',
        'attachWindow() requires a BrowserWindow',
      )
    }
    if (
      this.mode === 'full' &&
      typeof window.getNativeWindowHandle !== 'function'
    ) {
      throw new GuanceElectronError(
        'INVALID_ARGUMENT',
        'Full Mode requires BrowserWindow.getNativeWindowHandle()',
      )
    }
    if (window.webContents.session) {
      this.installSessionPreload(window.webContents.session)
    }
    return this.attach(window.webContents, { ...options, hostWindow: window })
  }

  attachWebContents(
    webContents: WebContentsLike,
    options: AttachOptions = {},
  ): WebContentsRegistration {
    return this.attach(webContents, options)
  }

  installSessionPreload(session: SessionLike): void {
    if (
      !session ||
      typeof session.getPreloads !== 'function' ||
      typeof session.setPreloads !== 'function'
    ) {
      throw new GuanceElectronError(
        'INVALID_ARGUMENT',
        'installSessionPreload() requires an Electron Session',
      )
    }
    const current = session.getPreloads()
    if (!current.includes(this.preloadPath)) {
      session.setPreloads([...current, this.preloadPath])
    }
  }

  dispose(): void {
    if (this.disposed) return
    this.disposed = true
    this.removeAutoAttach()
    for (const registration of [...this.registrations.values()]) {
      this.detach(registration)
    }
    this.electron.ipcMain.removeListener(
      CHANNELS.configuration,
      this.onConfiguration,
    )
    this.electron.ipcMain.removeListener(CHANNELS.message, this.onRendererMessage)
    this.transport.setCommandHandler(null)
    this.transport.dispose()
  }

  private attach(
    webContents: WebContentsLike,
    options: AttachOptions,
  ): WebContentsRegistration {
    if (this.disposed) {
      throw new GuanceElectronError(
        'INVALID_STATE',
        'Bridge controller is disposed',
      )
    }
    assertWebContents(webContents)
    if (this.registrations.has(webContents.id)) {
      throw new GuanceElectronError(
        'INVALID_STATE',
        `WebContents ${webContents.id} is already attached`,
      )
    }
    const hostWindow = options.hostWindow ||
      this.electron.BrowserWindow?.fromWebContents?.(webContents) || undefined
    if (!hostWindow) {
      throw new GuanceElectronError(
        'INVALID_ARGUMENT',
        'attachWebContents() requires hostWindow',
      )
    }
    const visible = options.visible ?? true
    const zIndex = options.zIndex ?? 0
    if (!Number.isInteger(zIndex)) {
      throw new GuanceElectronError(
        'INVALID_ARGUMENT',
        'zIndex must be an integer',
      )
    }
    const bounds = normalizeBounds(options.bounds)
    const hostAllowed = isAllowedHost(
      this.configuration.allowedWebViewHosts,
      webContents.getURL?.() || '',
    )
    const state = {} as RegistrationState
    Object.assign(state, {
      webContents,
      hostWindow,
      visible,
      zIndex,
      bounds,
      hostAllowed,
      disposed: false,
    })

    const onNavigation = (
      _event: unknown,
      url: string,
      _inPlace?: boolean,
      mainFrame?: boolean,
    ): void => {
      if (mainFrame === false) return
      const allowed = isAllowedHost(
        this.configuration.allowedWebViewHosts,
        url,
      )
      if (state.hostAllowed !== allowed) {
        state.hostAllowed = allowed
        this.updateTransport(state)
      }
    }
    const onDestroyed = (): void => this.detach(state)
    const onResize = (): void => {
      this.updateTransport(state)
    }
    state.onNavigation = onNavigation
    state.onDestroyed = onDestroyed
    state.onResize = onResize

    const targetSession = webContents.session ||
      this.electron.session?.defaultSession
    if (targetSession) this.installSessionPreload(targetSession)
    if (!this.registerTransport(state)) {
      throw new GuanceElectronError(
        'NATIVE_ERROR',
        `Owner rejected WebContents ${webContents.id}`,
      )
    }
    this.registrations.set(webContents.id, state)
    webContents.on('did-start-navigation', onNavigation)
    webContents.once('destroyed', onDestroyed)
    hostWindow.on('resize', onResize)

    return Object.freeze({
      update: (next: Pick<AttachOptions, 'visible' | 'zIndex' | 'bounds'>): void => {
        if (state.disposed) return
        if (next.visible !== undefined) state.visible = Boolean(next.visible)
        if (next.zIndex !== undefined) {
          if (!Number.isInteger(next.zIndex)) {
            throw new GuanceElectronError(
              'INVALID_ARGUMENT',
              'zIndex must be an integer',
            )
          }
          state.zIndex = next.zIndex
        }
        if (next.bounds !== undefined) {
          state.bounds = normalizeBounds(next.bounds)
        }
        if (!this.updateTransport(state)) {
          throw new GuanceElectronError(
            'NATIVE_ERROR',
            `Owner rejected WebContents ${webContents.id} update`,
          )
        }
      },
      dispose: () => this.detach(state),
    })
  }

  private registrationForSender(
    sender: WebContentsLike | undefined,
  ): RegistrationState | undefined {
    if (!sender) return undefined
    const registration = this.registrations.get(sender.id)
    return registration?.webContents === sender && !registration.disposed
      ? registration
      : undefined
  }

  private transportRegistration(
    state: RegistrationState,
  ): TransportRegistration {
    const nativeWindowHandle = this.mode === 'full'
      ? state.hostWindow?.getNativeWindowHandle?.()
      : undefined
    return {
      webContentsId: state.webContents.id,
      visible: state.visible && state.hostAllowed,
      zIndex: state.zIndex,
      bounds: state.bounds,
      nativeWindowHandle,
    }
  }

  private registerTransport(state: RegistrationState): boolean {
    return this.transport.register(this.transportRegistration(state))
  }

  private updateTransport(state: RegistrationState): boolean {
    if (state.disposed) return false
    return this.transport.update(this.transportRegistration(state))
  }

  private detach(state: RegistrationState): void {
    if (state.disposed) return
    state.disposed = true
    this.registrations.delete(state.webContents.id)
    state.webContents.removeListener('did-start-navigation', state.onNavigation)
    state.webContents.removeListener('destroyed', state.onDestroyed)
    if (state.onResize) state.hostWindow?.removeListener('resize', state.onResize)
    this.transport.unregister(state.webContents.id)
  }

  private dispatchCommand(webContentsId: number, command: string): void {
    const registration = this.registrations.get(webContentsId)
    if (
      !registration ||
      registration.disposed ||
      command !== FULL_SNAPSHOT_COMMAND ||
      registration.webContents.isDestroyed?.()
    ) return
    void Promise.resolve(
      registration.webContents.executeJavaScript?.(FULL_SNAPSHOT_SCRIPT),
    ).catch(() => undefined)
  }

  private installAutoAttach(): void {
    const app = this.electron.app
    const browserWindow = this.electron.BrowserWindow
    if (!app || !browserWindow?.getAllWindows) return
    this.autoAttachListener = (
      _event: unknown,
      window: BrowserWindowLike,
    ): void => {
      try {
        this.attachWindow(window)
      } catch {
        // Fail closed for this window without affecting other registrations.
      }
    }
    app.on('browser-window-created', this.autoAttachListener)
    for (const window of browserWindow.getAllWindows()) {
      if (this.registrations.has(window.webContents.id)) continue
      this.attachWindow(window)
    }
  }

  private removeAutoAttach(): void {
    if (this.autoAttachListener) {
      this.electron.app?.removeListener(
        'browser-window-created',
        this.autoAttachListener,
      )
      this.autoAttachListener = undefined
    }
  }
}

export function startBridgeController(
  electron: ElectronLike,
  transport: BridgeTransport,
  options: InternalBridgeStartOptions = {},
): Controller {
  if (!transport.configuration.enableTraceWebView) {
    transport.dispose()
    throw new GuanceElectronError(
      'INVALID_STATE',
      'Native RUM WebView tracing is disabled',
    )
  }
  return new Controller(
    electron,
    transport,
    options.preloadPath || defaultPreloadPath(),
    options.autoAttach !== false,
  )
}
