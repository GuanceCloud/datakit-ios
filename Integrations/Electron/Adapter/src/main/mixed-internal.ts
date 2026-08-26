import { startBridgeController, type ElectronLike } from './bridge'
import { GuanceElectronError } from './errors'
import { RemoteTransport } from './remote-transport'
import type { BridgeController, MixedModeConnectOptions } from './types'

type MixedModeInternalConnectOptions = MixedModeConnectOptions & {
  environment?: Readonly<Record<string, string | undefined>>
  preloadPath?: string
}

export const MIXED_MODE_ENVIRONMENT = Object.freeze({
  socketPath: 'GUANCE_ELECTRON_SOCKET_PATH',
  authenticationToken: 'GUANCE_ELECTRON_AUTH_TOKEN',
  protocolVersion: 'GUANCE_ELECTRON_PROTOCOL_VERSION',
})

export async function connectMixedModeWithElectron(
  electron: ElectronLike,
  options: MixedModeInternalConnectOptions = {},
): Promise<BridgeController> {
  const environment = options.environment || process.env
  const socketPath = environment[MIXED_MODE_ENVIRONMENT.socketPath]
  const authenticationToken =
    environment[MIXED_MODE_ENVIRONMENT.authenticationToken]
  const protocolVersion =
    environment[MIXED_MODE_ENVIRONMENT.protocolVersion]
  if (!socketPath || !authenticationToken) {
    throw new GuanceElectronError(
      'INVALID_ARGUMENT',
      'Mixed Mode launch credentials are missing',
    )
  }
  if (protocolVersion && protocolVersion !== '1') {
    throw new GuanceElectronError(
      'INVALID_ARGUMENT',
      `Unsupported Native Electron Bridge protocol ${protocolVersion}`,
    )
  }

  const transport = await RemoteTransport.connect({
    socketPath,
    authenticationToken,
    connectTimeoutMs: options.connectTimeoutMs,
  })
  return startBridgeController(electron, transport, options)
}
