import { spawn } from 'node:child_process'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptsDirectory = path.dirname(fileURLToPath(import.meta.url))
const projectRoot = path.resolve(scriptsDirectory, '..')
const nativePackage = path.join(projectRoot, 'macos')
const moduleCache = path.join(nativePackage, '.build', 'module-cache')

const child = spawn('swift', [
  'test', '--disable-sandbox', '--package-path', nativePackage,
], {
  cwd: projectRoot,
  env: {
    ...process.env,
    CLANG_MODULE_CACHE_PATH: moduleCache,
    SWIFTPM_MODULECACHE_OVERRIDE: moduleCache,
  },
  stdio: 'inherit',
})

child.once('error', (error) => {
  console.error(error)
  process.exitCode = 1
})
child.once('exit', (code) => {
  process.exitCode = code ?? 1
})
