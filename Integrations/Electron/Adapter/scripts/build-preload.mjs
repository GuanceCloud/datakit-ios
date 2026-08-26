import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { build } from 'esbuild'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')

await build({
  entryPoints: [path.join(root, 'src/preload/index.ts')],
  outfile: path.join(root, 'dist/preload.js'),
  bundle: true,
  platform: 'node',
  format: 'iife',
  target: 'node16',
  external: ['electron'],
  legalComments: 'none',
  sourcemap: false,
})
