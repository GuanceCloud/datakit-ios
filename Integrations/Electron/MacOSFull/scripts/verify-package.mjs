import fs from 'node:fs'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const required = [
  'dist/src/main/index.js',
  'dist/src/main/index.d.ts',
  'dist/src/preload/index.d.ts',
  'dist/preload.js',
  'adapter/dist/src/main/index.js',
  'adapter/dist/src/main/internal.js',
  'adapter/dist/preload.js',
  'native/guance_electron.node',
  'native/libGuanceElectronNative.dylib',
]
const missing = required.filter((value) => !fs.existsSync(path.join(root, value)))
if (missing.length) {
  throw new Error(`Package is incomplete:\n${missing.map((value) => `- ${value}`).join('\n')}`)
}
for (const entry of fs.readdirSync(path.join(root, 'adapter'), {
  recursive: true,
})) {
  if (/\.(?:node|dylib)$/u.test(String(entry)) || String(entry).includes('swift-runtime')) {
    throw new Error(`Vendored Adapter contains Native runtime content: ${entry}`)
  }
}
if (fs.existsSync(path.join(root, 'adapter', 'dist', 'test'))) {
  throw new Error('Vendored Adapter must not contain its test output')
}
const resourceBundles = fs.readdirSync(path.join(root, 'native'), {
  withFileTypes: true,
}).filter((entry) => entry.isDirectory() && entry.name.endsWith('.bundle'))
if (resourceBundles.length === 0) {
  throw new Error('Package is incomplete: native resource bundle is missing')
}
for (const relative of [
  'native/guance_electron.node',
  'native/libGuanceElectronNative.dylib',
]) {
  const file = path.join(root, relative)
  execFileSync('/usr/bin/lipo', [file, '-verify_arch', 'arm64', 'x86_64'])
  execFileSync('/usr/bin/codesign', ['--verify', '--verbose=2', file], {
    stdio: ['ignore', 'ignore', 'pipe'],
  })
}
const dylib = path.join(root, 'native/libGuanceElectronNative.dylib')
const swiftRuntime = path.join(root, 'native/swift-runtime')
if (fs.existsSync(swiftRuntime)) {
  throw new Error('Objective-C package must not contain native/swift-runtime')
}
const dependencies = execFileSync('/usr/bin/otool', ['-L', dylib], {
  encoding: 'utf8',
})
if (/libswift/i.test(dependencies)) {
  throw new Error('Native dylib still links a Swift runtime library')
}
const symbols = execFileSync('/usr/bin/nm', ['-gU', dylib], {
  encoding: 'utf8',
})
if (/(?:\$s|\bswift_)/.test(symbols)) {
  throw new Error('Native dylib still exports or imports Swift symbols')
}
const strings = execFileSync('/usr/bin/strings', [dylib], { encoding: 'utf8' })
if (/\/Users\/|MacOSFull\/\.build/.test(strings)) {
  throw new Error('Native dylib contains an absolute developer build path')
}
const loadCommands = execFileSync('/usr/bin/otool', ['-l', dylib], {
  encoding: 'utf8',
})
if (/path \/Applications\/Xcode|path \/Library\/Developer|swift-runtime/.test(loadCommands)) {
  throw new Error('Native dylib contains a developer-toolchain rpath')
}
console.log('Guanceelectron package contents verified')
