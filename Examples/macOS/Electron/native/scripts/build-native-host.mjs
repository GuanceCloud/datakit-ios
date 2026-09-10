import { spawn } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptsDirectory = path.dirname(fileURLToPath(import.meta.url))
const projectRoot = path.resolve(scriptsDirectory, '..')
const nativePackage = path.join(projectRoot, 'macos')
const outputDirectory = path.join(projectRoot, 'native-build')
const moduleCache = path.join(nativePackage, '.build', 'module-cache')
const environment = {
  ...process.env,
  CLANG_MODULE_CACHE_PATH: moduleCache,
  SWIFTPM_MODULECACHE_OVERRIDE: moduleCache,
}

function run(command, args, capture = false) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: projectRoot,
      env: environment,
      stdio: capture ? ['ignore', 'pipe', 'inherit'] : 'inherit',
    })
    let output = ''
    if (capture) child.stdout.on('data', (chunk) => { output += chunk })
    child.once('error', reject)
    child.once('exit', (code) => {
      if (code === 0) resolve(output.trim())
      else reject(new Error(`${command} exited with ${code}`))
    })
  })
}

async function build() {
  await run('swift', [
    'build', '--disable-sandbox', '--package-path', nativePackage,
    '--product', 'OrbitDeskNativeHost', '-c', 'debug',
  ])
  const binPath = await run('swift', [
    'build', '--disable-sandbox', '--package-path', nativePackage,
    '-c', 'debug', '--show-bin-path',
  ], true)
  const executable = path.join(binPath, 'OrbitDeskNativeHost')
  if (!fs.existsSync(executable)) {
    throw new Error(`External mode Native Host was not found: ${executable}`)
  }
  fs.mkdirSync(outputDirectory, { recursive: true })
  for (const entry of fs.readdirSync(outputDirectory, { withFileTypes: true })) {
    if (entry.name === 'OrbitDeskNativeHost' || entry.name.endsWith('.bundle')) {
      fs.rmSync(path.join(outputDirectory, entry.name), {
        recursive: entry.isDirectory(),
        force: true,
      })
    }
  }
  fs.rmSync(path.join(outputDirectory, 'electron.pid'), { force: true })
  const outputExecutable = path.join(outputDirectory, 'OrbitDeskNativeHost')
  fs.copyFileSync(executable, outputExecutable)
  fs.chmodSync(outputExecutable, 0o755)
  for (const entry of fs.readdirSync(binPath, { withFileTypes: true })) {
    if (entry.isDirectory() && entry.name.endsWith('.bundle')) {
      const destination = path.join(outputDirectory, entry.name)
      fs.rmSync(destination, { recursive: true, force: true })
      fs.cpSync(path.join(binPath, entry.name), destination, {
        recursive: true,
      })
    }
  }

  await run('/usr/bin/codesign', ['--force', '--sign', '-', outputExecutable])
  console.log(`External mode Native Host generated: ${outputExecutable}`)
}

build().catch((error) => {
  console.error(error instanceof Error ? error.message : error)
  process.exitCode = 1
})
