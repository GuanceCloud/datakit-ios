import path from 'node:path'
import { GuanceElectronError } from './errors'
import type { Bounds, BridgeConfiguration } from './types'

export interface NativeBinding {
  invoke(method: string, payload: string): Promise<string | undefined>
  getElectronBridgeConfiguration(): string | BridgeConfiguration
  registerElectronWebContents(
    handle: Buffer,
    webContentsId: number,
    slotId: number,
    visible: boolean,
    zIndex: number,
    bounds?: Bounds,
  ): boolean
  updateElectronWebContents(
    handle: Buffer,
    webContentsId: number,
    visible: boolean,
    zIndex: number,
    bounds?: Bounds,
  ): boolean
  receiveElectronWebContentsMessage(webContentsId: number, message: string): boolean
  unregisterElectronWebContents(webContentsId: number): void
  setElectronCommandHandler(handler: ((webContentsId: number, command: string) => void) | null): void
}

let overrideBinding: NativeBinding | undefined
let loadedBinding: NativeBinding | undefined

export function setNativeBindingForTesting(binding: NativeBinding | undefined): void {
  overrideBinding = binding
  loadedBinding = undefined
}

export function getNativeBinding(): NativeBinding {
  if (overrideBinding) return overrideBinding
  if (loadedBinding) return loadedBinding
  if (process.platform !== 'darwin') {
    throw new GuanceElectronError('NATIVE_UNAVAILABLE', 'Guanceelectron Native mode requires macOS')
  }
  const candidates = [
    // Flat ZIP delivery: GuanceElectronMacOS/index.js + native/.
    path.join(__dirname, 'native', 'guance_electron.node'),
    // Local npm package: dist/src/main/index.js + native/.
    path.join(__dirname, '..', '..', '..', 'native', 'guance_electron.node'),
    path.join(
      (process as NodeJS.Process & { resourcesPath?: string }).resourcesPath || '',
      'guance-electron',
      'guance_electron.node',
    ),
  ]
  let lastError: unknown
  for (const candidate of candidates) {
    try {
      // eslint-disable-next-line @typescript-eslint/no-var-requires
      loadedBinding = require(candidate) as NativeBinding
      return loadedBinding
    } catch (error) {
      lastError = error
    }
  }
  throw new GuanceElectronError(
    'NATIVE_UNAVAILABLE',
    'Could not load guance_electron.node; keep the addon and its resource bundles outside ASAR',
    { cause: lastError },
  )
}

export async function invokeNative<T = void>(method: string, payload: unknown = {}): Promise<T> {
  try {
    const result = await getNativeBinding().invoke(method, JSON.stringify(payload))
    if (!result) return undefined as T
    return JSON.parse(result) as T
  } catch (error) {
    if (error instanceof GuanceElectronError) throw error
    const native = error as { message?: string; domain?: string; code?: number }
    throw new GuanceElectronError('NATIVE_ERROR', native.message || `Native ${method} failed`, {
      nativeDomain: native.domain,
      nativeCode: native.code,
      cause: error,
    })
  }
}
