import { GuanceElectronError } from './errors'
import type { Bounds } from './types'

function invalid(message: string): never {
  throw new GuanceElectronError('INVALID_ARGUMENT', message)
}

function assertFinite(value: unknown, name: string): asserts value is number {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    invalid(`${name} must be a finite number`)
  }
}

export function normalizeBounds(value: Bounds | undefined): Bounds | undefined {
  if (value === undefined) return undefined
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    invalid('bounds must be an object')
  }
  for (const key of ['x', 'y', 'width', 'height'] as const) {
    assertFinite(value[key], `bounds.${key}`)
  }
  if (value.width <= 0 || value.height <= 0) {
    invalid('bounds must have positive width and height')
  }
  return { ...value }
}
