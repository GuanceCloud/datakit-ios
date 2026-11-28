import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import test from 'node:test'
import { nativeAddonLinkArguments, nativeSDKMetadata, runtimeFileHashes, validateNativeSDKSource } from './build-runtime.mjs'

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'guance-electron-build-'))
  t.after(() => fs.rmSync(root, { recursive: true, force: true }))
  fs.writeFileSync(path.join(root, 'GuanceSDK.podspec'), 's.version = "1.6.8-alpha.3"\n')
  fs.writeFileSync(path.join(root, 'Package.swift'), '.library(name: "GuanceElectronNative", type: .static, targets: [])\n')
  for (const file of ['Bridge/GuanceElectronBridge.m', 'Bridge/Public/GuanceElectronBridge.h', 'NodeAddon/guance_electron.mm']) {
    const destination = path.join(root, 'Sources/ElectronNative', file)
    fs.mkdirSync(path.dirname(destination), { recursive: true })
    fs.writeFileSync(destination, '// fixture\n')
  }
  return root
}

test('release metadata comes from the Native SDK and rejects a mismatched release tag', (t) => {
  const sdkRoot = fixture(t)
  assert.equal(nativeSDKMetadata(sdkRoot, 'v1.6.8-alpha.3').version, '1.6.8-alpha.3')
  assert.throws(() => nativeSDKMetadata(sdkRoot, '1.6.7'), /does not match Native SDK/u)
})

test('managed build requires the static SDK product and SDK-owned addon source', (t) => {
  const sdkRoot = fixture(t)
  assert.equal(validateNativeSDKSource(sdkRoot), sdkRoot)
  fs.writeFileSync(path.join(sdkRoot, 'Package.swift'), '.library(name: "GuanceElectronNative", type: .dynamic, targets: [])\n')
  assert.throws(() => validateNativeSDKSource(sdkRoot), /static GuanceElectronNative product/u)
})

test('addon links the SDK statically, preserves ObjC categories, and pins Node-API 8', () => {
  const args = nativeAddonLinkArguments({
    architecture: 'arm64', nodeHeadersPath: '/node/include', outputPath: '/output/guance_electron.node',
    sdkRoot: '/sdk', staticLibraryPath: '/build/libGuanceElectronNative.a',
  })
  assert.ok(args.includes('-Wl,-ObjC'))
  assert.ok(args.includes('-DNAPI_VERSION=8'))
  assert.ok(args.includes('/build/libGuanceElectronNative.a'))
  assert.equal(args.some((arg) => arg.includes('.dylib')), false)
})

for (const architecture of ['arm64', 'x86_64']) {
  test(`${architecture} addon requires macOS 12 like the Native SDK`, () => {
    const packageManifest = fs.readFileSync(new URL('../../Package.swift', import.meta.url), 'utf8')
    assert.match(packageManifest, /\.macOS\(\.v12\)/u)
    const args = nativeAddonLinkArguments({
      architecture, nodeHeadersPath: '/node/include', outputPath: '/output/guance_electron.node',
      sdkRoot: '/sdk', staticLibraryPath: '/build/libGuanceElectronNative.a',
    })
    assert.deepEqual(args.filter((arg) => arg.startsWith('-mmacosx-version-min=')), [
      '-mmacosx-version-min=12.0',
    ])
  })
}

test('resource changes alter manifest checksums and links are rejected', (t) => {
  const root = fixture(t)
  const runtime = path.join(root, 'runtime')
  fs.mkdirSync(runtime)
  fs.writeFileSync(path.join(runtime, 'guance_electron.node'), 'before')
  const before = runtimeFileHashes(runtime)
  fs.writeFileSync(path.join(runtime, 'guance_electron.node'), 'after')
  assert.notDeepEqual(runtimeFileHashes(runtime), before)
  fs.symlinkSync(root, path.join(runtime, 'outside'))
  assert.throws(() => runtimeFileHashes(runtime), /regular files and directories/u)
})
