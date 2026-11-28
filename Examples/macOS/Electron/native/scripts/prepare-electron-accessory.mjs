import { spawn } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { createRequire } from 'node:module'

const scriptsDirectory = path.dirname(fileURLToPath(import.meta.url))
const projectRoot = path.resolve(scriptsDirectory, '..')
const electronExecutable = createRequire(import.meta.url)('electron')
const sourceApp = path.resolve(path.dirname(electronExecutable), '../..')
const outputDirectory = path.join(projectRoot, 'native-build')
const accessoryApp = path.join(outputDirectory, 'OrbitDeskElectronAccessory.app')
const accessoryExecutable = path.join(
  accessoryApp,
  'Contents/MacOS/Electron',
)
const infoPlist = path.join(accessoryApp, 'Contents/Info.plist')
const sourceVersionFile = path.join(path.dirname(sourceApp), 'version')
const stampFile = path.join(
  accessoryApp,
  'Contents/Resources/.orbitdesk-accessory-version',
)

function run(command, args, capture = false) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: projectRoot,
      stdio: capture ? ['ignore', 'pipe', 'inherit'] : 'inherit',
    })
    let output = ''
    if (capture) child.stdout.on('data', (chunk) => { output += chunk })
    child.once('error', reject)
    child.once('exit', (code) => code === 0
      ? resolve(output.trim())
      : reject(new Error(`${command} exited with ${code}`)))
  })
}

async function prepare() {
  if (!fs.existsSync(sourceApp) || !fs.existsSync(sourceVersionFile)) {
    throw new Error('Electron is not installed; run npm install first')
  }
  const sourceVersion = fs.readFileSync(sourceVersionFile, 'utf8').trim()
  const expectedStamp = `accessory-v1:${sourceVersion}`
  if (fs.existsSync(accessoryExecutable) &&
      fs.existsSync(stampFile) &&
      fs.readFileSync(stampFile, 'utf8').trim() === expectedStamp) {
    const value = await run('/usr/bin/plutil', [
      '-extract', 'LSUIElement', 'raw', '-o', '-', infoPlist,
    ], true)
    if (value === 'true') {
      try {
        await run('/usr/bin/codesign', [
          '--verify', '--deep', '--strict', accessoryApp,
        ], true)
        console.log(`Accessory Electron ready: ${accessoryApp}`)
        return
      } catch {
        // Recreate a partially prepared or invalidly signed bundle below.
      }
    }
  }

  fs.mkdirSync(outputDirectory, { recursive: true })
  fs.rmSync(accessoryApp, { recursive: true, force: true })
  await run('/usr/bin/ditto', [sourceApp, accessoryApp])
  await run('/usr/bin/plutil', [
    '-replace', 'LSUIElement', '-bool', 'YES', infoPlist,
  ])
  await run('/usr/bin/plutil', [
    '-replace', 'CFBundleIdentifier',
    '-string', 'com.guance.example.OrbitDeskElectronAccessory', infoPlist,
  ])
  await run('/usr/bin/plutil', [
    '-replace', 'CFBundleDisplayName',
    '-string', 'OrbitDesk Electron UI', infoPlist,
  ])
  await run('/usr/bin/plutil', [
    '-replace', 'CFBundleName',
    '-string', 'OrbitDesk Electron UI', infoPlist,
  ])
  fs.writeFileSync(stampFile, `${expectedStamp}\n`)
  await run('/usr/bin/codesign', [
    '--force', '--deep', '--sign', '-', accessoryApp,
  ])
  console.log(`Accessory Electron generated: ${accessoryApp}`)
}

prepare().catch((error) => {
  console.error(error instanceof Error ? error.message : error)
  process.exitCode = 1
})
