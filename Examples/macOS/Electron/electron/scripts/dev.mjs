import { execFileSync, spawn } from 'node:child_process'
import fs from 'node:fs'
import net from 'node:net'
import path from 'node:path'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'

const scriptsDirectory = path.dirname(fileURLToPath(import.meta.url))
const projectRoot = path.resolve(scriptsDirectory, '..')
const smoke = process.argv.includes('--smoke')

function parseEnvironment(contents) {
  const values = {}
  for (const rawLine of contents.split(/\r?\n/u)) {
    const line = rawLine.trim()
    if (!line || line.startsWith('#')) continue
    const separator = line.indexOf('=')
    if (separator < 1) continue
    const key = line.slice(0, separator).trim()
    let value = line.slice(separator + 1).trim()
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1)
    }
    values[key] = value
  }
  return values
}

function loadEnvironment() {
  const values = {}
  for (const filename of ['.env', '.env.local']) {
    const file = path.join(projectRoot, filename)
    if (fs.existsSync(file)) Object.assign(values, parseEnvironment(fs.readFileSync(file, 'utf8')))
  }
  Object.assign(values, process.env)
  if (smoke) {
    const defaults = {
      GUANCE_NATIVE_APP_ID: 'appid_macos_managed_smoke',
      GUANCE_NATIVE_DATAKIT_URL: 'http://127.0.0.1:9529',
      GUANCE_NATIVE_DEBUG: 'false',
      GUANCE_NATIVE_SESSION_REPLAY: 'true',
      VITE_GUANCE_SERVICE: 'orbitdesk-managed-smoke',
      VITE_GUANCE_ENV: 'test',
    }
    for (const [key, value] of Object.entries(defaults)) {
      if (!values[key]) values[key] = value
    }
    values.GUANCE_EXAMPLE_SMOKE = '1'
  }
  return values
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

function run(command, args, environment) {
  execFileSync(command, args, { cwd: projectRoot, env: environment, stdio: 'inherit' })
}

function waitForChild(command, args, environment) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd: projectRoot, env: environment, stdio: 'inherit' })
    let timer
    const forward = (signal) => {
      if (child.exitCode === null && child.signalCode === null) child.kill(signal)
    }
    const interrupt = () => forward('SIGINT')
    const terminate = () => forward('SIGTERM')
    process.once('SIGINT', interrupt)
    process.once('SIGTERM', terminate)
    if (smoke) {
      timer = setTimeout(() => {
        console.error('[managed-example] smoke test timed out')
        forward('SIGTERM')
      }, 30_000)
    }
    child.once('error', reject)
    child.once('exit', (code, signal) => {
      clearTimeout(timer)
      process.removeListener('SIGINT', interrupt)
      process.removeListener('SIGTERM', terminate)
      if (code === 0) resolve()
      else reject(new Error(`${command} exited with ${code ?? signal}`))
    })
  })
}

const environment = loadEnvironment()
const electron = createRequire(import.meta.url)('electron')
let vite

try {
  if (smoke) {
    run(process.execPath, [path.join(projectRoot, 'node_modules/vite/bin/vite.js'), 'build'], environment)
  } else {
    const port = await availablePort()
    const viteURL = `http://127.0.0.1:${port}`
    environment.VITE_DEV_SERVER_URL = viteURL
    vite = spawn(path.join(projectRoot, 'node_modules/.bin/vite'), [
      '--host', '127.0.0.1', '--port', String(port), '--strictPort',
    ], { cwd: projectRoot, env: environment, stdio: 'inherit' })
    await waitFor(viteURL)
  }
  await waitForChild(electron, [projectRoot], environment)
} finally {
  if (vite?.exitCode === null) vite.kill('SIGTERM')
}
