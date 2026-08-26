import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const release = path.join(root, 'release', 'npm')
const temporaryRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'guance-electron-pack-'))

const manifests = [
  path.join(root, 'package.json'),
  path.join(root, 'Adapter', 'package.json'),
  path.join(root, 'MacOSFull', 'package.json'),
].map((file) => JSON.parse(fs.readFileSync(file, 'utf8')))
const versions = new Set(manifests.map(({ version }) => version))
if (versions.size !== 1) {
  throw new Error('Electron workspace, Adapter, and MacOSFull versions must match')
}

function copyPackage(source, destination, entries) {
  fs.mkdirSync(destination, { recursive: true })
  for (const entry of entries) {
    const from = path.join(source, entry)
    const to = path.join(destination, entry)
    if (!fs.existsSync(from)) throw new Error(`Missing package input: ${from}`)
    fs.cpSync(from, to, { recursive: true })
  }
}

function pack(directory) {
  return execFileSync('npm', ['pack', directory, '--pack-destination', release], {
    cwd: root,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'inherit'],
  }).trim().split(/\r?\n/u).at(-1)
}

function listArchive(archive) {
  return execFileSync('/usr/bin/tar', ['-tzf', archive], { encoding: 'utf8' })
    .split(/\r?\n/u)
    .filter(Boolean)
}

try {
  fs.rmSync(release, { recursive: true, force: true })
  fs.mkdirSync(release, { recursive: true })

  const adapterSource = path.join(root, 'Adapter')
  const adapterStage = path.join(temporaryRoot, 'adapter')
  copyPackage(adapterSource, adapterStage, ['package.json', 'README.md', 'dist'])
  const adapterManifestFile = path.join(adapterStage, 'package.json')
  const adapterManifest = JSON.parse(fs.readFileSync(adapterManifestFile, 'utf8'))
  delete adapterManifest.exports['./internal']
  fs.writeFileSync(adapterManifestFile, `${JSON.stringify(adapterManifest, null, 2)}\n`)
  const adapterArchiveName = pack(adapterStage)
  const adapterArchive = path.join(release, adapterArchiveName)
  const adapterEntries = listArchive(adapterArchive)
  if (adapterEntries.some((entry) =>
    /(?:^|\/)(?:native|swift-runtime)(?:\/|$)|\.(?:node|dylib)$/u.test(entry)
  )) {
    throw new Error('Adapter archive contains a Native runtime file')
  }

  const fullSource = path.join(root, 'MacOSFull')
  const fullStage = path.join(temporaryRoot, 'full')
  copyPackage(
    fullSource,
    fullStage,
    ['package.json', 'README.md', 'dist', 'adapter', 'native'],
  )
  const fullArchiveName = pack(fullStage)
  const fullArchive = path.join(release, fullArchiveName)
  const fullEntries = listArchive(fullArchive)
  for (const expected of [
    'package/native/guance_electron.node',
    'package/native/libGuanceElectronNative.dylib',
    'package/adapter/dist/src/main/index.js',
    'package/adapter/dist/preload.js',
  ]) {
    if (!fullEntries.includes(expected)) {
      throw new Error(`Full archive is missing ${expected}`)
    }
  }
  if (fullEntries.some((entry) => entry.includes('swift-runtime'))) {
    throw new Error('Full archive must not contain a Swift runtime directory')
  }

  console.log(`Built ${path.relative(root, adapterArchive)}`)
  console.log(`Built ${path.relative(root, fullArchive)}`)
} finally {
  fs.rmSync(temporaryRoot, { recursive: true, force: true })
}
