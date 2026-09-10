import { execFileSync } from 'node:child_process'
import { createHash } from 'node:crypto'
import fs from 'node:fs'
import path from 'node:path'

export const NODE_API_VERSION = 8

const PRODUCT_NAME = 'GuanceElectronNative'
const STATIC_LIBRARY_NAME = `lib${PRODUCT_NAME}.a`
const ADDON_NAME = 'guance_electron.node'
const MINIMUM_MACOS_VERSION = '10.14'

export function validateNativeSDKSource(sdkRoot) {
  const resolvedRoot = path.resolve(sdkRoot)
  const requiredFiles = [
    'Package.swift',
    'Sources/ElectronNative/Bridge/GuanceElectronBridge.m',
    'Sources/ElectronNative/Bridge/Public/GuanceElectronBridge.h',
    'Sources/ElectronNative/NodeAddon/guance_electron.mm',
  ]
  for (const relativePath of requiredFiles) {
    if (!fs.existsSync(path.join(resolvedRoot, relativePath))) {
      throw new Error(`Native SDK source is missing ${relativePath}: ${resolvedRoot}`)
    }
  }

  const packageManifest = fs.readFileSync(path.join(resolvedRoot, 'Package.swift'), 'utf8')
  const productDeclaration = new RegExp(
    `\\.library\\s*\\(\\s*name\\s*:\\s*"${PRODUCT_NAME}"\\s*,\\s*type\\s*:\\s*\\.static\\b`,
    'u',
  )
  if (!productDeclaration.test(packageManifest)) {
    throw new Error(`Native SDK Package.swift does not declare the static ${PRODUCT_NAME} product`)
  }
  return resolvedRoot
}

function run(command, args, options = {}) {
  return execFileSync(command, args, {
    cwd: options.cwd,
    env: options.env,
    encoding: options.capture ? 'utf8' : undefined,
    stdio: options.capture ? ['ignore', 'pipe', 'inherit'] : 'inherit',
  })
}

function repositoryStateAt(sdkRoot) {
  if (!fs.existsSync(path.join(sdkRoot, '.git'))) return {}
  try {
    const revision = run('git', ['rev-parse', 'HEAD'], {
      capture: true,
      cwd: sdkRoot,
      env: process.env,
    }).trim()
    const dirty = run('git', ['status', '--short'], {
      capture: true,
      cwd: sdkRoot,
      env: process.env,
    }).trim().length > 0
    return { revision, dirty }
  } catch {
    return {}
  }
}

export function nativeSDKMetadata(sdkRoot, requestedVersion) {
  const podspec = fs.readFileSync(path.join(sdkRoot, 'GuanceSDK.podspec'), 'utf8')
  const version = podspec.match(/s\.version\s*=\s*["']([^"']+)["']/u)?.[1]
  if (!version || !/^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$/u.test(version)) {
    throw new Error('GuanceSDK.podspec has no supported release version')
  }
  if (requestedVersion && requestedVersion.replace(/^v/u, '') !== version) {
    throw new Error(`Release version ${requestedVersion} does not match Native SDK ${version}`)
  }
  return { version, ...repositoryStateAt(sdkRoot) }
}

export function runtimeFileHashes(directory, relative = '') {
  const hashes = {}
  for (const entry of fs.readdirSync(path.join(directory, relative), { withFileTypes: true })) {
    const name = relative ? `${relative}/${entry.name}` : entry.name
    if (name === 'runtime-manifest.json') continue
    if (entry.isDirectory()) Object.assign(hashes, runtimeFileHashes(directory, name))
    else if (entry.isFile()) {
      hashes[name] = createHash('sha256').update(fs.readFileSync(path.join(directory, name))).digest('hex')
    } else throw new Error(`Runtime must contain only regular files and directories: ${name}`)
  }
  return hashes
}

function nodeHeaders() {
  const executable = fs.realpathSync(process.execPath)
  const candidates = [
    process.env.GUANCE_ELECTRON_NODE_HEADERS,
    process.env.npm_config_nodedir && path.join(process.env.npm_config_nodedir, 'include', 'node'),
    path.join(path.dirname(path.dirname(executable)), 'include', 'node'),
    process.config.variables.node_prefix && path.join(process.config.variables.node_prefix, 'include', 'node'),
    '/opt/homebrew/include/node',
    '/usr/local/include/node',
  ].filter(Boolean)
  const result = candidates.find((candidate) => fs.existsSync(path.join(candidate, 'node_api.h')))
  if (!result) throw new Error('Could not find node_api.h; set GUANCE_ELECTRON_NODE_HEADERS')
  return result
}

function removeDeveloperRpaths(file, environment) {
  const commands = run('/usr/bin/otool', ['-l', file], { capture: true, env: environment })
  const rpaths = commands.matchAll(/\n\s*path (\/[^\s]+) \(offset \d+\)/gu)
  for (const match of rpaths) {
    if (/^\/(?:Applications\/Xcode|Library\/Developer|Users\/)/u.test(match[1])) {
      run('/usr/bin/xcrun', ['install_name_tool', '-delete_rpath', match[1], file], { env: environment })
    }
  }
}

export function darwinArchitecture(nodeArchitecture) {
  if (nodeArchitecture === 'arm64') return 'arm64'
  if (nodeArchitecture === 'x64') return 'x86_64'
  throw new Error(`Unsupported Node architecture for macOS Native build: ${nodeArchitecture}`)
}

export function nativeAddonLinkArguments({
  architecture,
  nodeHeadersPath,
  outputPath,
  sdkRoot,
  staticLibraryPath,
}) {
  return [
    'clang++',
    '-std=c++17',
    `-DNAPI_VERSION=${NODE_API_VERSION}`,
    '-fobjc-arc',
    '-ObjC++',
    '-bundle',
    '-undefined',
    'dynamic_lookup',
    '-Wl,-ObjC',
    '-Wl,-dead_strip',
    ...(architecture ? ['-arch', architecture] : []),
    `-mmacosx-version-min=${MINIMUM_MACOS_VERSION}`,
    `-ffile-prefix-map=${sdkRoot}=.`,
    '-I',
    nodeHeadersPath,
    '-I',
    path.join(sdkRoot, 'Sources/ElectronNative/Bridge/Public'),
    path.join(sdkRoot, 'Sources/ElectronNative/NodeAddon/guance_electron.mm'),
    staticLibraryPath,
    '-framework',
    'Foundation',
    '-framework',
    'AppKit',
    '-o',
    outputPath,
  ]
}

function buildArchitecture({ buildRoot, architecture, configuration, environment, sdkRoot, stageRoot }) {
  const architectureName = architecture || darwinArchitecture(process.arch)
  const scratchPath = path.join(buildRoot, '.build', 'swift', `static-${configuration}-${architectureName}`)
  const releaseHygieneFlags = [
    '-Xcc',
    '-fvisibility=hidden',
    '-Xcc',
    `-ffile-prefix-map=${sdkRoot}=.`,
  ]
  const commonSwiftArguments = [
    '--disable-sandbox',
    '--package-path',
    sdkRoot,
    '--scratch-path',
    scratchPath,
    '-c',
    configuration,
    ...(architecture ? ['--arch', architecture] : []),
  ]
  run('swift', [
    'build',
    ...commonSwiftArguments,
    '--product',
    PRODUCT_NAME,
    ...releaseHygieneFlags,
  ], { cwd: buildRoot, env: environment })
  const bin = run('swift', ['build', ...commonSwiftArguments, '--show-bin-path'], {
    capture: true,
    cwd: buildRoot,
    env: environment,
  }).trim()
  const builtStaticLibrary = path.join(bin, STATIC_LIBRARY_NAME)
  if (!fs.existsSync(builtStaticLibrary)) {
    throw new Error(`Missing Native SDK product: ${builtStaticLibrary}`)
  }

  const stage = path.join(stageRoot, architectureName)
  fs.mkdirSync(stage, { recursive: true })
  const stagedAddon = path.join(stage, ADDON_NAME)

  run('/usr/bin/xcrun', nativeAddonLinkArguments({
    architecture,
    nodeHeadersPath: nodeHeaders(),
    outputPath: stagedAddon,
    sdkRoot,
    staticLibraryPath: builtStaticLibrary,
  }), { cwd: buildRoot, env: environment })
  removeDeveloperRpaths(stagedAddon, environment)

  return {
    addon: stagedAddon,
    architecture: architectureName,
    bin,
  }
}

function copyResourceBundles(bin, destination) {
  for (const entry of fs.readdirSync(bin, { withFileTypes: true })) {
    if (entry.isDirectory() && entry.name.endsWith('.bundle')) {
      fs.cpSync(path.join(bin, entry.name), path.join(destination, entry.name), { recursive: true })
    }
  }
}

function publishRuntime({ buildRoot, configuration, metadata, output, stages, universal }) {
  const publishStage = path.join(buildRoot, '.build', 'runtime-publish')
  fs.rmSync(publishStage, { recursive: true, force: true })
  fs.mkdirSync(publishStage, { recursive: true })

  if (universal) {
    run('/usr/bin/lipo', [
      '-create',
      ...stages.map((stage) => stage.addon),
      '-output',
      path.join(publishStage, ADDON_NAME),
    ], { env: process.env })
  } else {
    fs.copyFileSync(stages[0].addon, path.join(publishStage, ADDON_NAME))
  }
  copyResourceBundles(stages[0].bin, publishStage)

  for (const file of [ADDON_NAME]) {
    run('/usr/bin/codesign', ['--force', '--sign', '-', path.join(publishStage, file)], {
      env: process.env,
    })
  }

  const manifest = {
    schemaVersion: 1,
    mode: 'managed',
    platform: 'darwin',
    nativeSDKLinkage: 'static',
    architectures: stages.map((stage) => stage.architecture),
    configuration,
    nativeSDK: metadata,
    minimumMacOSVersion: MINIMUM_MACOS_VERSION,
    nodeAPIVersion: NODE_API_VERSION,
    files: runtimeFileHashes(publishStage),
  }
  fs.writeFileSync(
    path.join(publishStage, 'runtime-manifest.json'),
    `${JSON.stringify(manifest, null, 2)}\n`,
  )
  fs.rmSync(output, { recursive: true, force: true })
  fs.mkdirSync(path.dirname(output), { recursive: true })
  fs.renameSync(publishStage, output)
  return output
}

export function buildManagedRuntime({
  sdkRoot,
  version,
  architecture,
  buildRoot = path.join(sdkRoot, 'build', 'electron-native'),
  configuration = 'release',
  output = path.join(buildRoot, 'runtime'),
  universal = false,
}) {
  if (process.platform !== 'darwin') throw new Error('The macOS Native runtime can only be built on macOS')
  if (universal && architecture) {
    throw new Error('A managed runtime build cannot select both universal and a single architecture')
  }
  if (architecture && !['arm64', 'x86_64'].includes(architecture)) {
    throw new Error(`Unsupported macOS Native target architecture: ${architecture}`)
  }
  const resolvedBuildRoot = path.resolve(buildRoot)
  const resolvedOutput = path.resolve(output)
  const outputRelativePath = path.relative(resolvedBuildRoot, resolvedOutput)
  if (!outputRelativePath || outputRelativePath.startsWith('..') || path.isAbsolute(outputRelativePath)) {
    throw new Error(`Managed runtime output must be a child of its build root: ${resolvedOutput}`)
  }
  sdkRoot = validateNativeSDKSource(sdkRoot)
  const metadata = nativeSDKMetadata(sdkRoot, version)
  if (!['release', 'debug'].includes(configuration)) throw new Error('Unsupported build configuration')
  const environment = {
    ...process.env,
    MACOSX_DEPLOYMENT_TARGET: MINIMUM_MACOS_VERSION,
  }
  const targetName = universal ? 'universal' : architecture || 'current'
  const stageRoot = path.join(resolvedBuildRoot, '.build', `runtime-${targetName}`)
  fs.rmSync(stageRoot, { recursive: true, force: true })
  fs.mkdirSync(stageRoot, { recursive: true })
  const architectures = universal ? ['arm64', 'x86_64'] : [architecture]
  const stages = architectures.map((architecture) => buildArchitecture({
    buildRoot: resolvedBuildRoot,
    architecture,
    configuration,
    environment,
    sdkRoot,
    stageRoot,
  }))
  return publishRuntime({
    buildRoot: resolvedBuildRoot,
    configuration,
    metadata,
    output: resolvedOutput,
    stages,
    universal,
  })
}
