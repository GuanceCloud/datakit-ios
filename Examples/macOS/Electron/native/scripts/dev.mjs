import { spawn } from 'node:child_process'
import fs from 'node:fs'
import net from 'node:net'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { createRequire } from 'node:module'
import { loadProjectEnvironment } from './env.mjs'

const scriptsDirectory = path.dirname(fileURLToPath(import.meta.url))
const projectRoot = path.resolve(scriptsDirectory, '..')
const smoke = process.argv.includes('--smoke')
const environment = loadProjectEnvironment(projectRoot)
const installedElectronExecutable = createRequire(import.meta.url)('electron')
const electronExecutable = path.join(
  projectRoot,
  'native-build/OrbitDeskElectronAccessory.app/Contents/MacOS/Electron',
)
const nativeHostExecutable = path.join(projectRoot, 'native-build', 'OrbitDeskNativeHost')
const electronPIDFile = path.join(projectRoot, 'native-build', 'electron.pid')

if (smoke) {
  const defaults = {
    GUANCE_NATIVE_APP_ID: 'appid_macos_external_smoke',
    GUANCE_NATIVE_DATAKIT_URL: 'http://127.0.0.1:9529',
    GUANCE_NATIVE_DEBUG: 'false',
    GUANCE_NATIVE_SESSION_REPLAY: 'true',
    VITE_GUANCE_SERVICE: 'orbitdesk-external-smoke',
    VITE_GUANCE_ENV: 'test',
  }
  for (const [key, value] of Object.entries(defaults)) {
    if (!environment[key]) environment[key] = value
  }
  environment.GUANCE_EXAMPLE_SMOKE = '1'
}

function run(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: projectRoot,
      env: environment,
      stdio: 'inherit',
    })
    child.once('error', reject)
    child.once('exit', (code) => code === 0
      ? resolve()
      : reject(new Error(`${command} exited with ${code}`)))
  })
}

function availablePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer()
    server.once('error', reject)
    server.listen(0, '127.0.0.1', () => {
      const address = server.address()
      const port = typeof address === 'object' && address ? address.port : 0
      server.close(() => resolve(port))
    })
  })
}

async function waitFor(url) {
  const deadline = Date.now() + 30_000
  while (Date.now() < deadline) {
    try {
      const response = await fetch(url)
      if (response.ok) return
    } catch {}
    await new Promise((resolve) => setTimeout(resolve, 250))
  }
  throw new Error(`Timed out waiting for Vite: ${url}`)
}

if (!fs.existsSync(installedElectronExecutable)) {
  throw new Error('Electron is not installed; run npm install first.')
}

await run(process.execPath, [path.join(scriptsDirectory, 'build-native-host.mjs')])
await run(process.execPath, [path.join(scriptsDirectory, 'prepare-electron-accessory.mjs')])
if (!fs.existsSync(electronExecutable)) {
  throw new Error('Accessory Electron was not generated; run npm run prepare:electron.')
}

let vite
const childEnvironment = { ...environment }
if (smoke) {
  await run(process.execPath, [path.join(projectRoot, 'node_modules/vite/bin/vite.js'), 'build'])
} else {
  const port = await availablePort()
  const viteURL = `http://127.0.0.1:${port}`
  childEnvironment.VITE_DEV_SERVER_URL = viteURL
  vite = spawn(path.join(projectRoot, 'node_modules/.bin/vite'), [
    '--host', '127.0.0.1', '--port', String(port), '--strictPort',
  ], { cwd: projectRoot, env: childEnvironment, stdio: 'inherit' })
  await waitFor(viteURL)
}

const nativeHost = spawn(nativeHostExecutable, [], {
  cwd: projectRoot,
  env: {
    ...childEnvironment,
    ORBITDESK_ELECTRON_EXECUTABLE: electronExecutable,
    ORBITDESK_ELECTRON_PROJECT_ROOT: projectRoot,
    ORBITDESK_ELECTRON_PID_FILE: electronPIDFile,
  },
  stdio: 'inherit',
})

let closing = false
let smokeTimer

function readElectronPID() {
  if (!fs.existsSync(electronPIDFile)) return null
  const pid = Number.parseInt(fs.readFileSync(electronPIDFile, 'utf8'), 10)
  return Number.isInteger(pid) && pid > 1 ? pid : null
}

function signalElectron(pid, signal) {
  if (!Number.isInteger(pid) || pid <= 1) return
  try {
    process.kill(pid, signal)
  } catch (error) {
    if (error?.code !== 'ESRCH') throw error
  }
}

function close(code = 0) {
  if (closing) return
  closing = true
  clearTimeout(smokeTimer)
  const electronPID = readElectronPID()
  signalElectron(electronPID, 'SIGTERM')
  if (nativeHost.exitCode === null) nativeHost.kill('SIGTERM')
  if (vite?.exitCode === null) vite.kill('SIGTERM')
  signalElectron(electronPID, 'SIGKILL')
  try { fs.rmSync(electronPIDFile, { force: true }) } catch {}
  process.exit(code)
}

if (smoke) {
  smokeTimer = setTimeout(() => {
    console.error('[external-example] smoke test timed out')
    close(1)
  }, 60_000)
}

process.once('SIGINT', () => close(0))
process.once('SIGTERM', () => close(0))
nativeHost.once('exit', (code) => close(code ?? 0))
vite?.once('exit', (code) => { if (!closing) close(code ?? 1) })
