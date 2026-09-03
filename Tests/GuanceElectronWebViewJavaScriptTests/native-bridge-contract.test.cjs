'use strict'

const assert = require('node:assert/strict')
const path = require('node:path')
const test = require('node:test')

const REQUIRED_METHODS = [
  'getElectronBridgeConfiguration',
  'registerElectronWebContents',
  'updateElectronWebContents',
  'receiveElectronWebContentsMessage',
  'unregisterElectronWebContents',
  'setElectronCommandHandler',
]

test('GuanceElectronBridge exposes the embedded Native Adapter contract', {
  skip: process.platform !== 'darwin',
}, () => {
  const bridge = require(path.resolve(
    __dirname,
    '../../Sources/ElectronWebView/GuanceElectronRUM/GuanceElectronBridge.node',
  ))

  assert.deepEqual(
    Object.getOwnPropertyNames(bridge).sort(),
    [...REQUIRED_METHODS].sort(),
  )
  for (const method of REQUIRED_METHODS) {
    assert.equal(typeof bridge[method], 'function')
  }
})
