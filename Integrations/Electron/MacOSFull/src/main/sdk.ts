import { lifecycle } from './lifecycle'
import { invokeNative } from './native'
import type {
  Context,
  RemoteConfigUpdateResult,
  SdkConfiguration,
  UserData,
} from './types'
import {
  assertContext,
  assertIntegerRange,
  assertObject,
  assertString,
  validateSdkConfiguration,
} from './validation'

export const sdk = Object.freeze({
  async initialize(config: SdkConfiguration): Promise<void> {
    lifecycle.require(['idle'], 'sdk.initialize()')
    validateSdkConfiguration(config)
    await invokeNative('sdk.initialize', config)
    lifecycle.state = 'native-ready'
  },

  async setDatakitUrl(url: string): Promise<void> {
    lifecycle.require(['native-ready', 'feature-ready'], 'sdk.setDatakitUrl()')
    assertString(url, 'url')
    await invokeNative('sdk.setDatakitUrl', { url })
  },

  async setDataway(config: { url: string; clientToken: string }): Promise<void> {
    lifecycle.require(['native-ready', 'feature-ready'], 'sdk.setDataway()')
    assertObject(config, 'config')
    assertString(config.url, 'url')
    assertString(config.clientToken, 'clientToken')
    await invokeNative('sdk.setDataway', config)
  },

  async bindUser(user: UserData): Promise<void> {
    lifecycle.require(['native-ready', 'feature-ready', 'local-bridge-ready'], 'sdk.bindUser()')
    assertObject(user, 'user')
    assertString(user.id, 'user.id')
    assertContext(user.extra, 'user.extra')
    await invokeNative('sdk.bindUser', user)
  },

  async unbindUser(): Promise<void> {
    lifecycle.require(['native-ready', 'feature-ready', 'local-bridge-ready'], 'sdk.unbindUser()')
    await invokeNative('sdk.unbindUser')
  },

  async addGlobalContext(context: Context): Promise<void> {
    lifecycle.require(['native-ready', 'feature-ready', 'local-bridge-ready'], 'sdk.addGlobalContext()')
    assertContext(context)
    await invokeNative('sdk.addGlobalContext', context)
  },

  async addRumGlobalContext(context: Context): Promise<void> {
    lifecycle.require(['native-ready', 'feature-ready', 'local-bridge-ready'], 'sdk.addRumGlobalContext()')
    assertContext(context)
    await invokeNative('sdk.addRumGlobalContext', context)
  },

  async addLogGlobalContext(context: Context): Promise<void> {
    lifecycle.require(['native-ready', 'feature-ready', 'local-bridge-ready'], 'sdk.addLogGlobalContext()')
    assertContext(context)
    await invokeNative('sdk.addLogGlobalContext', context)
  },

  async trackExtensionEvents(groupIdentifier: string): Promise<unknown[]> {
    lifecycle.require(['native-ready', 'feature-ready'], 'sdk.trackExtensionEvents()')
    assertString(groupIdentifier, 'groupIdentifier')
    return invokeNative('sdk.trackExtensionEvents', { groupIdentifier })
  },

  async flush(): Promise<void> {
    lifecycle.require(['native-ready', 'feature-ready', 'local-bridge-ready'], 'sdk.flush()')
    await invokeNative('sdk.flush')
  },

  async clearData(): Promise<void> {
    lifecycle.require(['native-ready', 'feature-ready', 'local-bridge-ready'], 'sdk.clearData()')
    await invokeNative('sdk.clearData')
  },

  async updateRemoteConfig(options: { minimumInterval?: number } = {}): Promise<RemoteConfigUpdateResult> {
    lifecycle.require(['native-ready', 'feature-ready', 'local-bridge-ready'], 'sdk.updateRemoteConfig()')
    assertObject(options, 'options')
    assertIntegerRange(options.minimumInterval, 'minimumInterval', 0)
    return invokeNative('sdk.updateRemoteConfig', options)
  },

  async shutdown(): Promise<void> {
    lifecycle.require(['native-ready', 'feature-ready', 'local-bridge-ready'], 'sdk.shutdown()')
    lifecycle.disposeBridge()
    await invokeNative('sdk.shutdown')
    lifecycle.state = 'shutdown'
    lifecycle.rumConfigured = false
  },
})
