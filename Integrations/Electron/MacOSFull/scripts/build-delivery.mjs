import { execFileSync } from 'node:child_process'
import { createHash } from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { build } from 'esbuild'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const releaseRoot = path.join(root, 'release')
const deliveryName = 'GuanceElectronMacOS'
const deliveryRoot = path.join(releaseRoot, deliveryName)
const zipPath = path.join(releaseRoot, `${deliveryName}.zip`)
const nativeSource = path.join(root, 'native')

if (path.dirname(deliveryRoot) !== releaseRoot || path.dirname(zipPath) !== releaseRoot) {
  throw new Error('Refusing to clean an unexpected delivery path')
}

for (const required of [
  'dist/preload.js',
  'native/guance_electron.node',
  'native/libGuanceElectronNative.dylib',
]) {
  if (!fs.existsSync(path.join(root, required))) {
    throw new Error(`Missing delivery input: ${required}`)
  }
}

fs.rmSync(deliveryRoot, { recursive: true, force: true })
fs.rmSync(zipPath, { force: true })
fs.mkdirSync(deliveryRoot, { recursive: true })

const sharedBuildOptions = {
  bundle: true,
  platform: 'node',
  format: 'cjs',
  target: 'node16',
  external: ['electron'],
  legalComments: 'none',
  sourcemap: false,
}

await build({
  ...sharedBuildOptions,
  entryPoints: [path.join(root, 'src/main/index.ts')],
  outfile: path.join(deliveryRoot, 'index.js'),
})
fs.copyFileSync(path.join(root, 'dist/preload.js'), path.join(deliveryRoot, 'preload.js'))

fs.cpSync(nativeSource, path.join(deliveryRoot, 'native'), {
  recursive: true,
  preserveTimestamps: true,
  filter: (source) => path.basename(source) !== '.DS_Store',
})
if (fs.existsSync(path.join(deliveryRoot, 'native/swift-runtime'))) {
  throw new Error('Objective-C delivery must not contain swift-runtime')
}

execFileSync('/usr/bin/zip', ['-q', '-r', '-X', zipPath, deliveryName], {
  cwd: releaseRoot,
})

const digest = createHash('sha256').update(fs.readFileSync(zipPath)).digest('hex')
console.log(`Built ${zipPath}`)
console.log(`SHA-256 ${digest}`)
