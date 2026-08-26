import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const adapterRoot = path.resolve(root, '..', 'Adapter')
const source = path.join(adapterRoot, 'dist', 'preload.js')
const typesSource = path.join(adapterRoot, 'dist', 'src', 'preload', 'index.d.ts')
const output = path.join(root, 'dist', 'preload.js')
const typesOutput = path.join(root, 'dist', 'src', 'preload', 'index.d.ts')
const vendoredAdapter = path.join(root, 'adapter')

if (!fs.existsSync(source) || !fs.existsSync(typesSource)) {
  throw new Error('Build the Adapter before building MacOSFull')
}

fs.mkdirSync(path.dirname(output), { recursive: true })
fs.mkdirSync(path.dirname(typesOutput), { recursive: true })
fs.copyFileSync(source, output)
fs.copyFileSync(typesSource, typesOutput)

fs.rmSync(vendoredAdapter, { recursive: true, force: true })
fs.mkdirSync(vendoredAdapter, { recursive: true })
for (const entry of ['package.json', 'README.md']) {
  fs.cpSync(
    path.join(adapterRoot, entry),
    path.join(vendoredAdapter, entry),
    { recursive: true },
  )
}
fs.mkdirSync(path.join(vendoredAdapter, 'dist'), { recursive: true })
fs.cpSync(
  path.join(adapterRoot, 'dist', 'src'),
  path.join(vendoredAdapter, 'dist', 'src'),
  { recursive: true },
)
fs.copyFileSync(
  path.join(adapterRoot, 'dist', 'preload.js'),
  path.join(vendoredAdapter, 'dist', 'preload.js'),
)

function relativeModule(file, target) {
  let value = path.relative(path.dirname(file), target).split(path.sep).join('/')
  if (!value.startsWith('.')) value = `./${value}`
  return `${value}.js`
}

function rewriteAdapterImports(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const file = path.join(directory, entry.name)
    if (entry.isDirectory()) {
      rewriteAdapterImports(file)
      continue
    }
    if (!entry.name.endsWith('.js') && !entry.name.endsWith('.d.ts')) continue
    const publicEntry = relativeModule(
      file,
      path.join(vendoredAdapter, 'dist', 'src', 'main', 'index'),
    )
    const internalEntry = relativeModule(
      file,
      path.join(vendoredAdapter, 'dist', 'src', 'main', 'internal'),
    )
    const original = fs.readFileSync(file, 'utf8')
    const rewritten = original
      .replaceAll('@cloudcare/guance-electron-adapter/internal', internalEntry)
      .replaceAll('@cloudcare/guance-electron-adapter', publicEntry)
    fs.writeFileSync(file, rewritten)
  }
}

rewriteAdapterImports(path.join(root, 'dist'))
