import { lifecycle } from './lifecycle'
import { GuanceElectronError } from './errors'
import { invokeNative } from './native'
import type { SessionReplayConfiguration } from './types'
import { assertObject, assertSampling } from './validation'

export const sessionReplay = Object.freeze({
  async configure(config: SessionReplayConfiguration): Promise<void> {
    lifecycle.require(['feature-ready'], 'sessionReplay.configure()')
    if (!lifecycle.rumConfigured) {
      throw new GuanceElectronError(
        'INVALID_STATE',
        'sessionReplay.configure() requires rum.configure()',
      )
    }
    assertObject(config, 'config')
    assertSampling(config.sampleRate, 'sampleRate')
    assertSampling(config.sessionReplayOnErrorSampleRate, 'sessionReplayOnErrorSampleRate')
    await invokeNative('sessionReplay.configure', config)
  },
})
