import { lifecycle } from './lifecycle'
import { GuanceElectronError } from './errors'
import { invokeNative } from './native'
import type {
  Context,
  RumConfiguration,
  RumError,
  RumResourceContent,
  RumResourceMetrics,
} from './types'
import {
  assertContext,
  assertFinite,
  assertIntegerRange,
  assertObject,
  assertSampling,
  assertString,
} from './validation'

function requireRum(operation: string): void {
  lifecycle.require(['feature-ready', 'local-bridge-ready'], operation)
  if (!lifecycle.rumConfigured) {
    throw new GuanceElectronError('INVALID_STATE', `${operation} requires rum.configure()`)
  }
}

export const rum = Object.freeze({
  async configure(config: RumConfiguration): Promise<void> {
    lifecycle.require(['native-ready', 'feature-ready'], 'rum.configure()')
    assertObject(config, 'config')
    assertString(config.appId, 'appId')
    assertSampling(config.sampleRate, 'sampleRate')
    assertSampling(config.sessionOnErrorSampleRate, 'sessionOnErrorSampleRate')
    assertIntegerRange(config.freezeDurationMs, 'freezeDurationMs', 101)
    assertIntegerRange(config.rumCacheLimitCount, 'rumCacheLimitCount', 1)
    assertContext(config.globalContext, 'globalContext')
    await invokeNative('rum.configure', config)
    lifecycle.rumConfigured = true
    lifecycle.state = 'feature-ready'
  },

  async onCreateView(name: string, loadTime: number): Promise<void> {
    requireRum('rum.onCreateView()')
    assertString(name, 'name')
    assertFinite(loadTime, 'loadTime')
    await invokeNative('rum.onCreateView', { name, loadTime })
  },

  async startView(name: string, attributes?: Context): Promise<void> {
    requireRum('rum.startView()')
    assertString(name, 'name')
    assertContext(attributes, 'attributes')
    await invokeNative('rum.startView', { name, attributes })
  },

  async updateViewLoadingTime(duration: number): Promise<void> {
    requireRum('rum.updateViewLoadingTime()')
    assertFinite(duration, 'duration')
    await invokeNative('rum.updateViewLoadingTime', { duration })
  },

  async stopView(attributes?: Context): Promise<void> {
    requireRum('rum.stopView()')
    assertContext(attributes, 'attributes')
    await invokeNative('rum.stopView', { attributes })
  },

  async startAction(name: string, type: string, attributes?: Context): Promise<void> {
    requireRum('rum.startAction()')
    assertString(name, 'name')
    assertString(type, 'type')
    assertContext(attributes, 'attributes')
    await invokeNative('rum.startAction', { name, type, attributes })
  },

  async addAction(name: string, type: string, attributes?: Context): Promise<void> {
    requireRum('rum.addAction()')
    assertString(name, 'name')
    assertString(type, 'type')
    assertContext(attributes, 'attributes')
    await invokeNative('rum.addAction', { name, type, attributes })
  },

  async addError(error: RumError): Promise<void> {
    requireRum('rum.addError()')
    assertObject(error, 'error')
    assertString(error.type, 'error.type')
    assertString(error.message, 'error.message')
    assertString(error.stack, 'error.stack')
    assertContext(error.attributes, 'error.attributes')
    await invokeNative('rum.addError', error)
  },

  async addLongTask(stack: string, duration: number, attributes?: Context): Promise<void> {
    requireRum('rum.addLongTask()')
    assertString(stack, 'stack')
    assertFinite(duration, 'duration')
    assertContext(attributes, 'attributes')
    await invokeNative('rum.addLongTask', { stack, duration, attributes })
  },

  async startResource(key: string, attributes?: Context): Promise<void> {
    requireRum('rum.startResource()')
    assertString(key, 'key')
    assertContext(attributes, 'attributes')
    await invokeNative('rum.startResource', { key, attributes })
  },

  async stopResource(key: string, attributes?: Context): Promise<void> {
    requireRum('rum.stopResource()')
    assertString(key, 'key')
    assertContext(attributes, 'attributes')
    await invokeNative('rum.stopResource', { key, attributes })
  },

  async addResource(
    key: string,
    content: RumResourceContent,
    metrics?: RumResourceMetrics,
  ): Promise<void> {
    requireRum('rum.addResource()')
    assertString(key, 'key')
    assertObject(content, 'content')
    assertString(content.url, 'content.url')
    assertString(content.httpMethod, 'content.httpMethod')
    if (metrics !== undefined) assertObject(metrics, 'metrics')
    await invokeNative('rum.addResource', { key, content, metrics })
  },
})
