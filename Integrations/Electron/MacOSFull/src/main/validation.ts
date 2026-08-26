import { GuanceElectronError } from './errors'
import type { Bounds, Context, SdkConfiguration } from './types'

export function invalid(message: string): never {
  throw new GuanceElectronError('INVALID_ARGUMENT', message)
}

export function assertObject(value: unknown, name: string): asserts value is Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    invalid(`${name} must be an object`)
  }
}

export function assertString(value: unknown, name: string): asserts value is string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    invalid(`${name} must be a non-empty string`)
  }
}

export function assertFinite(value: unknown, name: string): asserts value is number {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    invalid(`${name} must be a finite number`)
  }
}

export function assertSampling(value: unknown, name: string): void {
  if (value === undefined) return
  assertFinite(value, name)
  if (!Number.isInteger(value) || value < 0 || value > 100) {
    invalid(`${name} must be an integer from 0 through 100`)
  }
}

export function assertIntegerRange(
  value: unknown,
  name: string,
  minimum: number,
  maximum = Number.MAX_SAFE_INTEGER,
): void {
  if (value === undefined) return
  assertFinite(value, name)
  if (!Number.isSafeInteger(value) || value < minimum || value > maximum) {
    invalid(`${name} must be an integer from ${minimum} through ${maximum}`)
  }
}

export function assertContext(value: unknown, name = 'context'): asserts value is Context {
  if (value === undefined) return
  assertObject(value, name)
  for (const [key, item] of Object.entries(value)) {
    if (!key || !['string', 'number', 'boolean'].includes(typeof item)) {
      invalid(`${name}.${key || '<empty>'} must be a string, number, or boolean`)
    }
  }
}

export function normalizeBounds(value: Bounds | undefined): Bounds | undefined {
  if (value === undefined) return undefined
  assertObject(value, 'bounds')
  for (const key of ['x', 'y', 'width', 'height'] as const) {
    assertFinite(value[key], `bounds.${key}`)
  }
  if (value.width <= 0 || value.height <= 0) {
    invalid('bounds must have positive width and height')
  }
  return { ...value }
}

function assertURL(value: string, name: string): void {
  assertString(value, name)
  try {
    const url = new URL(value)
    if (url.protocol !== 'http:' && url.protocol !== 'https:') invalid(`${name} must use HTTP or HTTPS`)
  } catch {
    invalid(`${name} must be a valid URL`)
  }
}

export function validateSdkConfiguration(config: SdkConfiguration): void {
  assertObject(config, 'config')
  const hasDatakit = typeof config.datakitUrl === 'string'
  const hasDataway = typeof config.datawayUrl === 'string' || typeof config.clientToken === 'string'
  if (hasDatakit === hasDataway) {
    invalid('configure exactly one upload mode: datakitUrl or datawayUrl with clientToken')
  }
  if (hasDatakit) assertURL(config.datakitUrl!, 'datakitUrl')
  if (hasDataway) {
    assertURL(config.datawayUrl!, 'datawayUrl')
    assertString(config.clientToken, 'clientToken')
  }
  assertContext(config.globalContext, 'globalContext')
  assertIntegerRange(config.syncPageSize, 'syncPageSize', 5)
  assertIntegerRange(config.syncSleepTime, 'syncSleepTime', 0, 5000)
  assertIntegerRange(config.dbCacheLimit, 'dbCacheLimit', 1)
  assertIntegerRange(
    config.remoteConfigMiniUpdateInterval,
    'remoteConfigMiniUpdateInterval',
    0,
  )
}
