import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { findNativeSDKRoot } from './paths.mjs'

const scriptsDirectory = path.dirname(fileURLToPath(import.meta.url))
const root = path.resolve(scriptsDirectory, '..')
const nativeSDKRoot = findNativeSDKRoot(root)
const nativeHeaderRoot = path.join(root, 'NativeBridge/Public')
const output = path.join(root, 'native')
const staleSwiftRuntime = path.join(output, 'swift-runtime')
const configuration = process.argv.includes('--debug') ? 'debug' : 'release'
const environment = { ...process.env, MACOSX_DEPLOYMENT_TARGET: '10.14' }
const releaseHygieneFlags = [
  '-Xlinker',
  '-dead_strip',
  '-Xcc',
  '-fvisibility=hidden',
  '-Xcc',
  `-ffile-prefix-map=${nativeSDKRoot}=.`,
  '-Xcc',
  `-ffile-prefix-map=${root}=.`,
]

function run(command, args, options = {}) {
  return execFileSync(command, args, {
    cwd: options.cwd || root,
    env: environment,
    encoding: options.capture ? 'utf8' : undefined,
    stdio: options.capture ? ['ignore', 'pipe', 'inherit'] : 'inherit',
  })
}

function nodeHeaders() {
  const executable = fs.realpathSync(process.execPath)
  const candidates = [
    process.env.GUANCE_ELECTRON_NODE_HEADERS,
    process.env.npm_config_nodedir && path.join(process.env.npm_config_nodedir, 'include', 'node'),
    path.join(path.dirname(path.dirname(executable)), 'include', 'node'),
    process.config.variables.node_prefix && path.join(process.config.variables.node_prefix, 'include', 'node'),
  ].filter(Boolean)
  const result = candidates.find((candidate) => fs.existsSync(path.join(candidate, 'node_api.h')))
  if (!result) throw new Error('Could not find node_api.h; set GUANCE_ELECTRON_NODE_HEADERS')
  return result
}

function removeDeveloperRpaths(file) {
  const commands = run('/usr/bin/otool', ['-l', file], { capture: true })
  const rpaths = commands.matchAll(/\n\s*path (\/[^\s]+) \(offset \d+\)/g)
  for (const match of rpaths) {
    run('/usr/bin/xcrun', ['install_name_tool', '-delete_rpath', match[1], file])
  }
}

function assertObjectiveCOnly(file) {
  const dependencies = run('/usr/bin/otool', ['-L', file], { capture: true })
  if (/libswift/i.test(dependencies)) {
    throw new Error(`${file} still links a Swift runtime library`)
  }
  const symbols = run('/usr/bin/nm', ['-gU', file], { capture: true })
  if (/(?:\$s|\bswift_)/.test(symbols)) {
    throw new Error(`${file} still exports or imports Swift symbols`)
  }
}

run('swift', [
  'build',
  '--disable-sandbox',
  '-c',
  configuration,
  '--product',
  'GuanceElectronNative',
  ...releaseHygieneFlags,
], { cwd: root })
const bin = run(
  'swift',
  ['build', '--disable-sandbox', '-c', configuration, '--show-bin-path'],
  { capture: true, cwd: root },
).trim()
const dylib = path.join(bin, 'libGuanceElectronNative.dylib')
if (!fs.existsSync(dylib)) throw new Error(`Missing Objective-C bridge: ${dylib}`)

fs.mkdirSync(output, { recursive: true })
fs.rmSync(staleSwiftRuntime, { recursive: true, force: true })
for (const entry of fs.readdirSync(output, { withFileTypes: true })) {
  if (entry.isDirectory() && entry.name.endsWith('.bundle')) {
    fs.rmSync(path.join(output, entry.name), { recursive: true, force: true })
  }
}
fs.copyFileSync(dylib, path.join(output, 'libGuanceElectronNative.dylib'))
removeDeveloperRpaths(path.join(output, 'libGuanceElectronNative.dylib'))
assertObjectiveCOnly(path.join(output, 'libGuanceElectronNative.dylib'))
for (const entry of fs.readdirSync(bin, { withFileTypes: true })) {
  if (entry.isDirectory() && entry.name.endsWith('.bundle')) {
    fs.cpSync(path.join(bin, entry.name), path.join(output, entry.name), { recursive: true })
  }
}

run('/usr/bin/xcrun', [
  'clang++',
  '-std=c++17',
  '-fobjc-arc',
  '-ObjC++',
  '-bundle',
  '-undefined',
  'dynamic_lookup',
  '-mmacosx-version-min=10.14',
  '-I',
  nodeHeaders(),
  '-I',
  nativeHeaderRoot,
  path.join(root, 'src/native/guance_electron.mm'),
  '-L',
  output,
  '-lGuanceElectronNative',
  '-Wl,-rpath,@loader_path',
  '-framework',
  'Foundation',
  '-framework',
  'AppKit',
  '-o',
  path.join(output, 'guance_electron.node'),
])

for (const file of ['libGuanceElectronNative.dylib', 'guance_electron.node']) {
  run('/usr/bin/codesign', ['--force', '--sign', '-', path.join(output, file)])
}

console.log(`Built Objective-C ${path.join(output, 'guance_electron.node')}`)
