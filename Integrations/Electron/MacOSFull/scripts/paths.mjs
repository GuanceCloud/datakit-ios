import fs from 'node:fs'
import path from 'node:path'

function isNativeSDKRoot(candidate) {
  return fs.existsSync(path.join(candidate, 'Package.swift'))
    && fs.existsSync(path.join(
      candidate,
      'Sources/ElectronWebView/Public/FTElectronWebViewHandler.h',
    ))
}

export function findNativeSDKRoot(componentRoot) {
  const configured = process.env.GUANCE_NATIVE_SDK_ROOT
  if (configured) {
    const resolved = path.resolve(configured)
    if (!isNativeSDKRoot(resolved)) {
      throw new Error(`GUANCE_NATIVE_SDK_ROOT is not a Guance Native SDK checkout: ${resolved}`)
    }
    return resolved
  }

  let ancestor = componentRoot
  while (true) {
    if (isNativeSDKRoot(ancestor)) return ancestor
    const parent = path.dirname(ancestor)
    if (parent === ancestor) break
    ancestor = parent
  }

  const sibling = path.resolve(
    componentRoot,
    '..',
    '..',
    'ft-sdk-ios-macos-sessionreplay',
  )
  if (isNativeSDKRoot(sibling)) return sibling

  throw new Error(
    'Could not locate the Guance Native SDK; set GUANCE_NATIVE_SDK_ROOT',
  )
}
