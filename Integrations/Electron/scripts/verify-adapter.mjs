import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const adapter = path.join(root, 'Adapter')

for (const relative of [
  'dist/src/main/index.js',
  'dist/src/main/index.d.ts',
  'dist/src/main/internal.js',
  'dist/src/preload/index.d.ts',
  'dist/preload.js',
]) {
  if (!fs.existsSync(path.join(adapter, relative))) {
    throw new Error(`Adapter is incomplete: ${relative}`)
  }
}

const forbidden = []
function visit(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const current = path.join(directory, entry.name)
    if (entry.isDirectory()) {
      if (entry.name.endsWith('.bundle') || entry.name === 'swift-runtime') {
        forbidden.push(path.relative(adapter, current))
      } else if (entry.name !== 'node_modules') {
        visit(current)
      }
    } else if (/\.(?:node|dylib)$/u.test(entry.name)) {
      forbidden.push(path.relative(adapter, current))
    }
  }
}
visit(adapter)

if (forbidden.length > 0) {
  throw new Error(`Adapter contains Native runtime files:\n${forbidden.join('\n')}`)
}

const publicEntry = await import(path.join(adapter, 'dist/src/main/index.js'))
const exports = Object.keys(publicEntry.default || publicEntry).sort()
if (exports.join(',') !== 'GuanceElectronError,connectMixedMode') {
  throw new Error(`Unexpected Adapter public exports: ${exports.join(', ')}`)
}

console.log('JavaScript-only Electron Adapter verified')
