import { GuanceElectronError } from './errors'
import type { BridgeConfiguration } from './types'

export function parseBridgeConfiguration(
  value: string | BridgeConfiguration,
): Readonly<BridgeConfiguration> {
  const candidate = typeof value === 'string' ? JSON.parse(value) : value
  if (!candidate || typeof candidate !== 'object') {
    throw new GuanceElectronError('NATIVE_ERROR', 'Bridge configuration is invalid')
  }
  const maximum = Number(candidate.maximumMessageBytes || 1024 * 1024)
  if (!Number.isSafeInteger(maximum) || maximum <= 0) {
    throw new GuanceElectronError(
      'NATIVE_ERROR',
      'Bridge maximumMessageBytes is invalid',
    )
  }
  return Object.freeze({
    ...candidate,
    enableTraceWebView: candidate.enableTraceWebView === true,
    allowedWebViewHosts: Array.isArray(candidate.allowedWebViewHosts)
      ? candidate.allowedWebViewHosts.map(String)
      : null,
    maximumMessageBytes: maximum,
  })
}

export function isAllowedHost(allowed: string[] | null, url: string): boolean {
  if (allowed === null) return true
  let current = ''
  try {
    current = new URL(url).hostname.toLowerCase()
  } catch {
    return false
  }
  return allowed.some((item) => {
    const host = item.trim().toLowerCase()
    return host.length > 0 && (current === host || current.endsWith(`.${host}`))
  })
}
