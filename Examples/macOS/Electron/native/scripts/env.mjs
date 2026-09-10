import fs from 'node:fs'
import path from 'node:path'

function parse(contents) {
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

export function loadProjectEnvironment(projectRoot) {
  const values = {}
  for (const filename of ['.env', '.env.local']) {
    const filePath = path.join(projectRoot, filename)
    if (fs.existsSync(filePath)) {
      Object.assign(values, parse(fs.readFileSync(filePath, 'utf8')))
    }
  }
  return { ...values, ...process.env }
}
