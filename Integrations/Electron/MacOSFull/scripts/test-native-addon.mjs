import path from 'node:path'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const require = createRequire(import.meta.url)
const { sdk, rum, logger, trace } = require(
  path.join(root, 'dist/src/main/index.js')
)

await sdk.initialize({
  datakitUrl: 'http://127.0.0.1:9529',
  autoSync: false,
  debug: false,
})
await rum.configure({
  appId: 'guance-electron-native-addon-test',
  enableTraceUserView: false,
  enableTraceUserAction: false,
  enableTraceUserResource: false,
  enableTrackAppCrash: false,
  enableTrackAppFreeze: false,
  enableTrackAppANR: false,
  enableTraceWebView: true,
})
await logger.configure({ enableCustomLog: true })
await logger.log('Native addon smoke test', 'electron-test')
await trace.configure({
  sampleRate: 100,
  traceType: 'traceparent',
  enableAutoTrace: false,
})
const headers = await trace.getHeaders('https://example.com/native-addon-test')
if (!headers || typeof headers !== 'object') {
  throw new Error('Native trace headers did not return an object')
}
await sdk.shutdown()
console.log('Native addon public API smoke test passed')
