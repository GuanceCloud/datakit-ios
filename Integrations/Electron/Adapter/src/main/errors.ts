export type GuanceElectronErrorCode =
  | 'INVALID_ARGUMENT'
  | 'INVALID_STATE'
  | 'NATIVE_UNAVAILABLE'
  | 'NATIVE_ERROR'
  | 'PROTOCOL_ERROR'
  | 'REMOTE_DISABLED'
  | 'REMOTE_DISCONNECTED'
  | 'HANDSHAKE_TIMEOUT'

export class GuanceElectronError extends Error {
  readonly code: GuanceElectronErrorCode
  readonly nativeDomain?: string
  readonly nativeCode?: number

  constructor(
    code: GuanceElectronErrorCode,
    message: string,
    options: { nativeDomain?: string; nativeCode?: number; cause?: unknown } = {},
  ) {
    super(message, { cause: options.cause })
    this.name = 'GuanceElectronError'
    this.code = code
    this.nativeDomain = options.nativeDomain
    this.nativeCode = options.nativeCode
  }
}
