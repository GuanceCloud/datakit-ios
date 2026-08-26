import {
  parseBridgeConfiguration,
  type BridgeConfiguration,
  type BridgeTransport,
  type TransportRegistration,
} from '@cloudcare/guance-electron-adapter/internal'
import type { NativeBinding } from './native'

let nextSlotId = Date.now() * 1000

function allocateSlotId(): number {
  nextSlotId += 1
  if (!Number.isSafeInteger(nextSlotId)) nextSlotId = Date.now() * 1000
  return nextSlotId
}

export class EmbeddedTransport implements BridgeTransport {
  readonly mode = 'full' as const
  readonly configuration: Readonly<BridgeConfiguration>

  constructor(private readonly binding: NativeBinding) {
    this.configuration = parseBridgeConfiguration(
      binding.getElectronBridgeConfiguration(),
    )
  }

  get connected(): boolean { return true }

  register(registration: TransportRegistration): boolean {
    if (!registration.nativeWindowHandle) return false
    return this.binding.registerElectronWebContents(
      registration.nativeWindowHandle,
      registration.webContentsId,
      allocateSlotId(),
      registration.visible,
      registration.zIndex,
      registration.bounds,
    )
  }

  update(registration: TransportRegistration): boolean {
    if (!registration.nativeWindowHandle) return false
    return this.binding.updateElectronWebContents(
      registration.nativeWindowHandle,
      registration.webContentsId,
      registration.visible,
      registration.zIndex,
      registration.bounds,
    )
  }

  sendEvent(webContentsId: number, messageQueue: string): boolean {
    return this.binding.receiveElectronWebContentsMessage(
      webContentsId,
      messageQueue,
    )
  }

  unregister(webContentsId: number): void {
    this.binding.unregisterElectronWebContents(webContentsId)
  }

  setCommandHandler(
    handler: ((webContentsId: number, command: string) => void) | null,
  ): void {
    this.binding.setElectronCommandHandler(handler)
  }

  dispose(): void {
    this.binding.setElectronCommandHandler(null)
  }
}
