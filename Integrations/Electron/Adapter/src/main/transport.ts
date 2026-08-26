import type { Bounds, BridgeConfiguration } from './types'

export interface TransportRegistration {
  webContentsId: number
  visible: boolean
  zIndex: number
  bounds?: Bounds
  nativeWindowHandle?: Buffer
}

export interface BridgeTransport {
  readonly mode: 'full' | 'mixed'
  readonly connected: boolean
  readonly configuration: Readonly<BridgeConfiguration>
  register(registration: TransportRegistration): boolean
  update(registration: TransportRegistration): boolean
  sendEvent(webContentsId: number, messageQueue: string): boolean
  unregister(webContentsId: number): void
  setCommandHandler(
    handler: ((webContentsId: number, command: string) => void) | null,
  ): void
  dispose(): void
}
