import { lifecycle } from './lifecycle'
import { invokeNative } from './native'
import type { Context, LoggerConfiguration, LogStatus } from './types'
import {
  assertContext,
  assertIntegerRange,
  assertObject,
  assertSampling,
  assertString,
} from './validation'

export const logger = Object.freeze({
  async configure(config: LoggerConfiguration): Promise<void> {
    lifecycle.require(['native-ready', 'feature-ready'], 'logger.configure()')
    assertObject(config, 'config')
    assertSampling(config.sampleRate, 'sampleRate')
    assertIntegerRange(config.logCacheLimitCount, 'logCacheLimitCount', 1)
    assertContext(config.globalContext, 'globalContext')
    await invokeNative('logger.configure', config)
    lifecycle.state = 'feature-ready'
  },

  async log(content: string, status: LogStatus, attributes?: Context): Promise<void> {
    lifecycle.require(['feature-ready', 'local-bridge-ready'], 'logger.log()')
    assertString(content, 'content')
    assertString(status, 'status')
    assertContext(attributes, 'attributes')
    await invokeNative('logger.log', { content, status, attributes })
  },
})
