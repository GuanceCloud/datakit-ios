import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')

for (const relative of ['Adapter/dist', 'MacOSFull/dist', 'release']) {
  const target = path.join(root, relative)
  if (!target.startsWith(`${root}${path.sep}`)) {
    throw new Error(`Refusing to clean unexpected path: ${target}`)
  }
  fs.rmSync(target, { recursive: true, force: true })
}
