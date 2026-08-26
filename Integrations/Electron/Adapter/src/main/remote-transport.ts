import { randomUUID } from 'node:crypto'
import net from 'node:net'
import { parseBridgeConfiguration } from './bridge-configuration'
import { GuanceElectronError } from './errors'
import type { BridgeTransport, TransportRegistration } from './transport'
import type { BridgeConfiguration } from './types'

const PROTOCOL_VERSION = 1
const MAXIMUM_ENVELOPE_BYTES = 2 * 1024 * 1024
const MAXIMUM_PENDING_BYTES = 4 * 1024 * 1024
const MAXIMUM_PENDING_REQUESTS = 4096

interface RemoteTransportOptions {
  socketPath: string
  authenticationToken: string
  connectTimeoutMs?: number
}

type ProtocolMessage = Record<string, unknown> & {
  protocolVersion?: unknown
  type?: unknown
  connectionID?: unknown
}

export class RemoteTransport implements BridgeTransport {
  readonly mode = 'mixed' as const
  private readonly connectionID = randomUUID()
  private readonly socket: net.Socket
  private configurationStorage: Readonly<BridgeConfiguration> = Object.freeze({
    enableTraceWebView: false,
    allowedWebViewHosts: null,
    maximumMessageBytes: 1024 * 1024,
  })
  private input = Buffer.alloc(0)
  private nextSequence = 1
  private ready = false
  private disposed = false
  private commandHandler: ((webContentsId: number, command: string) => void) | null = null
  private readonly registrations = new Set<number>()
  private readonly pendingRequests = new Map<string, string>()

  private constructor(
    private readonly options: RemoteTransportOptions,
    private resolveReady: (transport: RemoteTransport) => void,
    private rejectReady: (error: Error) => void,
  ) {
    this.socket = net.createConnection({ path: options.socketPath })
    this.socket.on('connect', () => this.sendHello())
    this.socket.on('data', (data) => this.consume(data))
    this.socket.on('error', (error) => this.fail(error))
    this.socket.on('close', () => {
      const wasReady = this.ready
      this.ready = false
      this.registrations.clear()
      this.pendingRequests.clear()
      if (!wasReady && !this.disposed) {
        this.rejectReady(new GuanceElectronError(
          'NATIVE_UNAVAILABLE',
          'Native Electron Bridge closed before authentication completed',
        ))
      }
    })
  }

  static connect(options: RemoteTransportOptions): Promise<RemoteTransport> {
    if (!options.socketPath || !options.authenticationToken) {
      return Promise.reject(new GuanceElectronError(
        'INVALID_ARGUMENT',
        'Mixed Mode requires Native launch credentials',
      ))
    }
    return new Promise((resolve, reject) => {
      const transport = new RemoteTransport(options, resolve, reject)
      const timeout = setTimeout(() => {
        if (transport.ready) return
        transport.socket.destroy()
        reject(new GuanceElectronError(
          'NATIVE_UNAVAILABLE',
          'Timed out connecting to the Native Electron Bridge',
        ))
      }, options.connectTimeoutMs ?? 5000)
      timeout.unref?.()
      const resolveOnce = transport.resolveReady
      transport.resolveReady = (value): void => {
        clearTimeout(timeout)
        resolveOnce(value)
      }
      const rejectOnce = transport.rejectReady
      transport.rejectReady = (error): void => {
        clearTimeout(timeout)
        rejectOnce(error)
      }
    })
  }

  get connected(): boolean {
    return this.ready && !this.disposed && !this.socket.destroyed
  }

  get configuration(): Readonly<BridgeConfiguration> {
    return this.configurationStorage
  }

  register(registration: TransportRegistration): boolean {
    if (!this.connected || this.registrations.has(registration.webContentsId)) {
      return false
    }
    this.registrations.add(registration.webContentsId)
    if (!this.send('register', {
      webContentsID: registration.webContentsId,
      visible: registration.visible,
    })) {
      this.registrations.delete(registration.webContentsId)
      return false
    }
    return true
  }

  update(registration: TransportRegistration): boolean {
    return this.registrations.has(registration.webContentsId) && this.send('update', {
      webContentsID: registration.webContentsId,
      visible: registration.visible,
    })
  }

  sendEvent(webContentsId: number, messageQueue: string): boolean {
    if (
      !this.registrations.has(webContentsId) ||
      Buffer.byteLength(messageQueue, 'utf8') >
        this.configuration.maximumMessageBytes
    ) return false
    return this.send('event', {
      webContentsID: webContentsId,
      payload: messageQueue,
    })
  }

  unregister(webContentsId: number): void {
    if (!this.registrations.delete(webContentsId)) return
    this.send('unregister', { webContentsID: webContentsId })
  }

  setCommandHandler(
    handler: ((webContentsId: number, command: string) => void) | null,
  ): void {
    this.commandHandler = handler
  }

  dispose(): void {
    if (this.disposed) return
    if (this.connected) this.send('close', {})
    this.disposed = true
    this.ready = false
    this.registrations.clear()
    this.pendingRequests.clear()
    this.commandHandler = null
    this.socket.end()
    const forceClose = setTimeout(() => this.socket.destroy(), 100)
    forceClose.unref?.()
  }

  private sendHello(): void {
    this.write({
      protocolVersion: PROTOCOL_VERSION,
      type: 'hello',
      connectionID: this.connectionID,
      authenticationToken: this.options.authenticationToken,
    })
  }

  private send(type: string, payload: Record<string, unknown>): boolean {
    if (!this.connected) return false
    if (
      this.pendingRequests.size >= MAXIMUM_PENDING_REQUESTS ||
      !Number.isSafeInteger(this.nextSequence)
    ) {
      this.socket.destroy()
      return false
    }
    const sequence = this.nextSequence
    this.nextSequence += 1
    const requestID = String(sequence)
    this.pendingRequests.set(requestID, type)
    if (!this.write({
      protocolVersion: PROTOCOL_VERSION,
      type,
      connectionID: this.connectionID,
      sequence,
      requestID,
      ...payload,
    })) {
      this.pendingRequests.delete(requestID)
      return false
    }
    return true
  }

  private write(message: ProtocolMessage): boolean {
    if (this.disposed || this.socket.destroyed) return false
    let data: Buffer
    try {
      data = Buffer.from(`${JSON.stringify(message)}\n`, 'utf8')
    } catch {
      return false
    }
    if (
      data.length > MAXIMUM_ENVELOPE_BYTES ||
      this.socket.writableLength + data.length > MAXIMUM_PENDING_BYTES
    ) {
      this.socket.destroy()
      return false
    }
    this.socket.write(data)
    return true
  }

  private consume(data: Buffer): void {
    this.input = Buffer.concat([this.input, data])
    if (this.input.length > MAXIMUM_ENVELOPE_BYTES) {
      this.socket.destroy()
      return
    }
    while (true) {
      const newline = this.input.indexOf(0x0a)
      if (newline < 0) return
      if (newline === 0 || newline > MAXIMUM_ENVELOPE_BYTES) {
        this.socket.destroy()
        return
      }
      const line = this.input.subarray(0, newline)
      this.input = this.input.subarray(newline + 1)
      let message: ProtocolMessage
      try {
        message = JSON.parse(line.toString('utf8')) as ProtocolMessage
      } catch {
        this.socket.destroy()
        return
      }
      this.handleMessage(message)
      if (this.socket.destroyed) return
    }
  }

  private handleMessage(message: ProtocolMessage): void {
    if (
      message.protocolVersion !== PROTOCOL_VERSION ||
      message.connectionID !== this.connectionID ||
      typeof message.type !== 'string'
    ) {
      this.socket.destroy()
      return
    }

    if (!this.ready) {
      if (message.type !== 'ready' || !message.configuration) {
        this.socket.destroy()
        return
      }
      try {
        this.configurationStorage = parseBridgeConfiguration(
          message.configuration as BridgeConfiguration,
        )
      } catch (error) {
        this.fail(error)
        return
      }
      this.ready = true
      this.resolveReady(this)
      return
    }

    if (message.type === 'ack') {
      const requestID = typeof message.requestID === 'string'
        ? message.requestID
        : undefined
      const requestType = requestID
        ? this.pendingRequests.get(requestID)
        : undefined
      if (requestID) this.pendingRequests.delete(requestID)
      if (message.ok !== true && requestType !== 'event') {
        this.socket.destroy()
      }
      return
    }

    if (message.type === 'command') {
      const webContentsID = Number(message.webContentsID)
      const command = message.command
      if (
        Number.isSafeInteger(webContentsID) &&
        this.registrations.has(webContentsID) &&
        typeof command === 'string'
      ) {
        this.commandHandler?.(webContentsID, command)
      }
      return
    }

    this.socket.destroy()
  }

  private fail(error: unknown): void {
    const failure = error instanceof Error
      ? error
      : new Error('Native Electron Bridge failed')
    if (!this.ready && !this.disposed) this.rejectReady(failure)
    this.socket.destroy()
  }
}
