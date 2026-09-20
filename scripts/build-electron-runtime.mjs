#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { createHash } from 'node:crypto'
import { fileURLToPath } from 'node:url'
import { buildManagedRuntime, nativeSDKMetadata } from './electron/build-runtime.mjs'

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url))
const sdkRoot = path.resolve(scriptDirectory, '..')
const usage = 'Usage: node scripts/build-electron-runtime.mjs [--version SDK_VERSION] [--debug]'
let version
let configuration = 'release'
try {
  for (let index = 2; index < process.argv.length; index += 1) {
    const argument = process.argv[index]
    if (argument === '--help' || argument === '-h') {
      console.log(usage)
      process.exit(0)
    }
    if (argument === '--debug') { configuration = 'debug'; continue }
    if (argument !== '--version' || !process.argv[index + 1]) {
      throw new Error(usage)
    }
    const value = process.argv[++index]
    version = value
  }
  const metadata = nativeSDKMetadata(sdkRoot, version)
  const buildRoot = path.join(sdkRoot, 'build', 'electron-native')
  const target = 'universal'
  const packageRoot = path.join(buildRoot, target)
  const runtime = buildManagedRuntime({
    sdkRoot,
    version,
    configuration,
    buildRoot,
    output: path.join(packageRoot, 'runtime'),
    universal: true,
  })
  execFileSync(process.execPath, [path.join(scriptDirectory, 'verify-electron-runtime.mjs'), runtime], {
    stdio: 'inherit',
  })
  // Debug builds are for Native SDK development, never release download assets.
  if (configuration === 'debug') process.exit(0)
  const filename = 'guance-electron-runtime-' + metadata.version + '-darwin-universal.tar.gz'
  const archive = path.join(buildRoot, filename)
  execFileSync('/usr/bin/tar', ['-czf', archive, '-C', packageRoot, 'runtime'], {
    env: { ...process.env, COPYFILE_DISABLE: '1' },
    stdio: 'inherit',
  })
  const checksum = createHash('sha256').update(fs.readFileSync(archive)).digest('hex')
  fs.writeFileSync(archive + '.sha256', checksum + '  ' + filename + '\n')
  console.log('Packaged ' + archive)
} catch (error) {
  console.error('build-electron-runtime: ' + error.message)
  process.exitCode = 1
}
