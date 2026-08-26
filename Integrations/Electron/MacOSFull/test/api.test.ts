import assert from 'node:assert/strict'
import { afterEach, beforeEach, test } from 'node:test'
import { lifecycle } from '../src/main/lifecycle'
import { logger } from '../src/main/logger'
import { setNativeBindingForTesting } from '../src/main/native'
import { rum } from '../src/main/rum'
import { sdk } from '../src/main/sdk'
import { sessionReplay } from '../src/main/session-replay'
import { trace } from '../src/main/trace'
import { TestNativeBinding } from './helpers'
import { bridge } from '../src/main/index'

let native: TestNativeBinding

beforeEach(() => {
  lifecycle.resetForTesting()
  native = new TestNativeBinding()
  setNativeBindingForTesting(native)
})

afterEach(() => {
  setNativeBindingForTesting(undefined)
  lifecycle.resetForTesting()
})

test('local owner initializes once and configures native RUM with native sampling units', async () => {
  await sdk.initialize({ datakitUrl: 'http://127.0.0.1:9529', debug: true })
  await rum.configure({ appId: 'electron-app', sampleRate: 75, enableTraceWebView: true })

  assert.deepEqual(native.invocations.map((item) => item.method), [
    'sdk.initialize',
    'rum.configure',
  ])
  assert.equal((native.invocations[1].payload as { sampleRate: number }).sampleRate, 75)
  await assert.rejects(
    sdk.initialize({ datakitUrl: 'http://127.0.0.1:9529' }),
    /not allowed/,
  )
})

test('SDK upload configuration is mutually exclusive', async () => {
  await assert.rejects(
    sdk.initialize({ datakitUrl: 'http://localhost', datawayUrl: 'https://dataway', clientToken: 'x' } as never),
    /exactly one upload mode/,
  )
  assert.equal(native.invocations.length, 0)
})

test('public bridge surface is limited to same-process startup and window selection', () => {
  assert.deepEqual(Object.keys(bridge).sort(), ['attachWindow', 'dispose', 'start'])
  assert.equal('startLocal' in bridge, false)
  assert.equal('startRemote' in bridge, false)
})

test('same-process component retains the complete adapted Native API surface', async () => {
  await sdk.initialize({ datakitUrl: 'http://127.0.0.1:9529' })
  await sdk.setDatakitUrl('http://127.0.0.1:9528')
  await sdk.setDataway({ url: 'https://dataway.example.com', clientToken: 'token' })
  await sdk.bindUser({ id: 'user-1', name: 'Electron user' })
  await sdk.unbindUser()
  await sdk.addGlobalContext({ global: 'value' })
  await sdk.addRumGlobalContext({ rum: 'value' })
  await sdk.addLogGlobalContext({ log: 'value' })
  await sdk.trackExtensionEvents('group-1')
  await sdk.flush()
  await sdk.clearData()
  await sdk.updateRemoteConfig({ minimumInterval: 60 })

  await rum.configure({ appId: 'electron-app', enableTraceWebView: true })
  await rum.onCreateView('main', 1)
  await rum.startView('main', { source: 'test' })
  await rum.updateViewLoadingTime(2)
  await rum.stopView({ result: 'ok' })
  await rum.startAction('click', 'click')
  await rum.addAction('submit', 'click')
  await rum.addError({ type: 'test', message: 'error', stack: 'stack' })
  await rum.addLongTask('stack', 10)
  await rum.startResource('resource-1')
  await rum.stopResource('resource-1')
  await rum.addResource('resource-1', {
    url: 'https://example.com',
    httpMethod: 'GET',
    statusCode: 200,
  }, { duration: 10 })

  await logger.configure({ enableCustomLog: true })
  await logger.log('message', 'info')
  await trace.configure({ traceType: 'traceparent' })
  await trace.getHeaders('https://example.com')
  await sessionReplay.configure({ sampleRate: 100 })
  await sdk.shutdown()

  assert.deepEqual(native.invocations.map((item) => item.method), [
    'sdk.initialize',
    'sdk.setDatakitUrl',
    'sdk.setDataway',
    'sdk.bindUser',
    'sdk.unbindUser',
    'sdk.addGlobalContext',
    'sdk.addRumGlobalContext',
    'sdk.addLogGlobalContext',
    'sdk.trackExtensionEvents',
    'sdk.flush',
    'sdk.clearData',
    'sdk.updateRemoteConfig',
    'rum.configure',
    'rum.onCreateView',
    'rum.startView',
    'rum.updateViewLoadingTime',
    'rum.stopView',
    'rum.startAction',
    'rum.addAction',
    'rum.addError',
    'rum.addLongTask',
    'rum.startResource',
    'rum.stopResource',
    'rum.addResource',
    'logger.configure',
    'logger.log',
    'trace.configure',
    'trace.getHeaders',
    'sessionReplay.configure',
    'sdk.shutdown',
  ])
})
