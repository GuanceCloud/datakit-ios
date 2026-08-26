import { lifecycle } from './lifecycle'
import { invokeNative } from './native'
import type { TraceConfiguration } from './types'
import { assertObject, assertSampling, assertString } from './validation'

export const trace = Object.freeze({
  async configure(config: TraceConfiguration): Promise<void> {
    lifecycle.require(['native-ready', 'feature-ready'], 'trace.configure()')
    assertObject(config, 'config')
    assertSampling(config.sampleRate, 'sampleRate')
    await invokeNative('trace.configure', config)
    lifecycle.state = 'feature-ready'
  },

  async getHeaders(url: string, resourceKey?: string): Promise<Record<string, string>> {
    lifecycle.require(['feature-ready', 'local-bridge-ready'], 'trace.getHeaders()')
    assertString(url, 'url')
    if (resourceKey !== undefined) assertString(resourceKey, 'resourceKey')
    return invokeNative('trace.getHeaders', { url, resourceKey })
  },
})
