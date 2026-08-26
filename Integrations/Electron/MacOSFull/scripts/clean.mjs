import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const dist = path.join(root, 'dist')
const adapter = path.join(root, 'adapter')

if (path.dirname(dist) !== root || path.basename(dist) !== 'dist') {
  throw new Error(`Refusing to clean unexpected output path: ${dist}`)
}

fs.rmSync(dist, { recursive: true, force: true })
fs.rmSync(adapter, { recursive: true, force: true })
