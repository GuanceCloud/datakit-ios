import type { ElectronLike } from './bridge'
import { connectMixedModeWithElectron } from './mixed-internal'
import type { MixedModeBridge, MixedModeConnectOptions } from './types'

export async function connectMixedMode(
  options: MixedModeConnectOptions = {},
): Promise<MixedModeBridge> {
  const controller = await connectMixedModeWithElectron(
    require('electron') as ElectronLike,
    options,
  )
  return Object.freeze({
    get connected(): boolean { return controller.connected },
    attachWindow: controller.attachWindow.bind(controller),
    dispose: controller.dispose.bind(controller),
  })
}

export type { MixedModeBridge, MixedModeConnectOptions } from './types'
export {
  GuanceElectronError,
  type GuanceElectronErrorCode,
} from './errors'
export type {
  AttachOptions,
  Bounds,
  BridgeStartOptions,
  BrowserWindowLike,
  WebContentsRegistration,
} from './types'
