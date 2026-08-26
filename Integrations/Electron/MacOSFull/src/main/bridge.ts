import path from 'node:path'
import {
  CHANNELS,
  GuanceElectronError,
  startBridgeController,
  type Controller,
  type ElectronLike,
  type InternalBridgeStartOptions,
} from '@cloudcare/guance-electron-adapter/internal'
import { EmbeddedTransport } from './embedded-transport'
import { lifecycle } from './lifecycle'
import { getNativeBinding } from './native'
import type {
  BridgeStartOptions,
  BrowserWindowLike,
} from './types'

export { CHANNELS }

function defaultPreloadPath(): string {
  return path.join(__dirname, '..', '..', 'preload.js')
}

export function createBridgeApi(electron: ElectronLike) {
  let activeController: Controller | undefined

  const dispose = (): void => {
    const controller = activeController
    activeController = undefined
    lifecycle.setBridgeDisposer(undefined)
    controller?.dispose()
  }

  return Object.freeze({
    async start(
      options: InternalBridgeStartOptions = {},
    ): Promise<Controller> {
      lifecycle.require(['feature-ready'], 'bridge.start()')
      if (!lifecycle.rumConfigured) {
        throw new GuanceElectronError(
          'INVALID_STATE',
          'bridge.start() requires rum.configure()',
        )
      }
      activeController = startBridgeController(
        electron,
        new EmbeddedTransport(getNativeBinding()),
        {
          ...options,
          preloadPath: options.preloadPath || defaultPreloadPath(),
        },
      )
      lifecycle.setBridgeDisposer(dispose)
      lifecycle.state = 'local-bridge-ready'
      return activeController
    },

    attachWindow(window: BrowserWindowLike): void {
      if (!activeController) {
        throw new GuanceElectronError(
          'INVALID_STATE',
          'bridge.attachWindow() requires bridge.start()',
        )
      }
      activeController.attachWindow(window)
    },

    dispose,
  })
}

let defaultApi: ReturnType<typeof createBridgeApi> | undefined

function getDefaultApi(): ReturnType<typeof createBridgeApi> {
  if (!defaultApi) {
    defaultApi = createBridgeApi(require('electron') as ElectronLike)
  }
  return defaultApi
}

export const bridge = Object.freeze({
  async start(options: BridgeStartOptions = {}): Promise<void> {
    await getDefaultApi().start(options)
  },
  attachWindow: (window: BrowserWindowLike): void =>
    getDefaultApi().attachWindow(window),
  dispose: () => getDefaultApi().dispose(),
})
