import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import test from 'node:test'
import { fileURLToPath } from 'node:url'
import { runInNewContext } from 'node:vm'

const root = fileURLToPath(new URL('../../', import.meta.url))
// Ruby/Psych is available on the macOS build runners; no npm install is needed.
const parsed = spawnSync('ruby', ['-rjson', '-ryaml', '-e', `
  puts JSON.generate(ARGV.map do |path|
    workflow = YAML.safe_load(File.read(path), aliases: false)
    # Psych uses YAML 1.1, where the unquoted GitHub key "on" is a boolean.
    workflow["on"] = workflow.delete(true) if workflow.key?(true)
    workflow
  end)
`, ...['publish-ios-release-assets.yml', 'publish-electron-runtime.yml']
  .map((name) => path.join(root, '.github/workflows', name))], { encoding: 'utf8' })
assert.equal(parsed.status, 0, parsed.stderr || parsed.error?.message)
const [sdk, electron] = JSON.parse(parsed.stdout)
const sdkJob = sdk.jobs['publish-assets']
const sdkUpload = sdkJob.steps.find((step) => step.run?.includes('gh release upload'))
const electronUpload = electron.jobs.publish.steps.find((step) => step.run?.includes('gh release upload'))

const sdkFiles = [
  'GuanceSDK.xcframework.zip',
  'GuanceSDK-DisableSwizzlingResource.xcframework.zip',
  'GuanceSessionReplay.xcframework.zip',
  'GuanceWidgetExtension.xcframework.zip',
  'GuanceWidgetExtension-DisableSwizzlingResource.xcframework.zip',
  'GuanceSDK-Dynamic.xcframework.zip',
  'GuanceSDK-Dynamic-DisableSwizzlingResource.xcframework.zip',
  'GuanceSessionReplay-Dynamic.xcframework.zip',
]
const runtimeName = (tag) => `guance-electron-runtime-${tag.replace(/^v/u, '')}-darwin-universal.tar.gz`

function temporaryDirectory(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'guance-publish-test-'))
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }))
  return directory
}

// Evaluate only the boolean/string expression subset used by these workflows.
// Job dependency assertions below check that GitHub's default success gate remains.
function evaluate(expression, context) {
  if (typeof expression !== 'string') return expression
  return runInNewContext(expression.replace(/^\s*\$\{\{([\s\S]*)\}\}\s*$/u, '$1'), {
    ...context,
    contains: (value, needle) => String(value).toLowerCase().includes(String(needle).toLowerCase()),
  }, { timeout: 1000 })
}

function context(event = 'push', tag = '1.6.8', overwrite = false) {
  return {
    github: { event_name: event, ref_name: tag, ref: `refs/tags/${tag}` },
    inputs: event === 'workflow_dispatch' ? { tag, overwrite, asset_preset: 'all', asset_names: '' } : {},
    needs: { build: { outputs: { tag } } },
  }
}

function render(script, values) {
  return script.replace(/\$\{\{([\s\S]*?)\}\}/gu, (_, expression) => String(evaluate(expression, values) ?? ''))
}

function resolveSDKOptions(directory, values) {
  const output = path.join(directory, 'github-env')
  const step = sdkJob.steps.find((item) => item.name === 'Resolve publish options')
  const result = spawnSync('/bin/bash', ['-c', render(step.run, values)], {
    encoding: 'utf8',
    env: { PATH: process.env.PATH, GITHUB_REF_NAME: values.github.ref_name, GITHUB_ENV: output },
  })
  assert.equal(result.status, 0, result.stderr)
  return Object.fromEntries(fs.readFileSync(output, 'utf8').trimEnd().split('\n').map((line) => {
    const separator = line.indexOf('=')
    return [line.slice(0, separator), line.slice(separator + 1)]
  }))
}

const mockGH = `
view_count=0
gh() {
  printf '%s\\t' "$@" >> "$TEST_GH_CALLS"
  printf '\\n' >> "$TEST_GH_CALLS"
  [[ "$1" == release ]] || return 99
  case "$2" in
    view)
      view_count=$((view_count + 1))
      case "$TEST_SCENARIO" in
        existing|upload-fails|duplicate) return 0 ;;
        new|race) [[ "$view_count" -gt 1 ]] ;;
        unavailable) return 3 ;;
        *) return 99 ;;
      esac
      ;;
    create)
      case "$TEST_SCENARIO" in
        new) return 0 ;;
        race) return 1 ;; # The other workflow created the Release after our view.
        unavailable) return 3 ;;
        *) return 99 ;;
      esac
      ;;
    upload)
      [[ "$TEST_SCENARIO" != upload-fails ]] || return 7
      if [[ "$TEST_SCENARIO" == duplicate ]]; then
        for argument in "$@"; do
          [[ "$argument" != --clobber ]] || return 0
        done
        return 1
      fi
      ;;
    *) return 99 ;;
  esac
}
`

function upload(t, kind, scenario, { event = 'push', tag = '1.6.8', overwrite = false,
  preset = 'all', assetNames = '' } = {}) {
  const directory = temporaryDirectory(t)
  const trace = path.join(directory, 'gh-calls')
  fs.writeFileSync(trace, '')
  fs.mkdirSync(path.join(directory, 'build'))
  fs.mkdirSync(path.join(directory, 'assets'))
  for (const file of sdkFiles) fs.writeFileSync(path.join(directory, 'build', file), 'fixture')
  for (const file of [runtimeName(tag), runtimeName(tag) + '.sha256']) {
    fs.writeFileSync(path.join(directory, 'assets', file), 'fixture')
  }
  const step = kind === 'sdk' ? sdkUpload : electronUpload
  const values = context(event, tag, overwrite)
  if (event === 'workflow_dispatch') {
    values.inputs.asset_preset = preset
    values.inputs.asset_names = assetNames
  }
  // Only install the workflow's overwrite env if it actually declares it.
  // This makes the test fail when the input is not wired into the upload step.
  const overwriteEnv = step.env?.OVERWRITE_ASSETS === undefined ? {}
    : { OVERWRITE_ASSETS: String(evaluate(step.env.OVERWRITE_ASSETS, values)) }
  const result = spawnSync('/bin/bash', ['-c', mockGH + step.run], {
    cwd: directory,
    encoding: 'utf8',
    env: {
      PATH: process.env.PATH,
      TEST_GH_CALLS: trace,
      TEST_SCENARIO: scenario,
      SDK_TAG: tag,
      ...(kind === 'sdk' ? resolveSDKOptions(directory, values) : overwriteEnv),
    },
  })
  const calls = fs.readFileSync(trace, 'utf8').split('\n').filter(Boolean)
    .map((line) => line.split('\t').slice(0, -1))
  return { ...result, calls }
}

for (const kind of ['sdk', 'electron']) {
  for (const [scenario, status, verbs] of [
    ['existing', 0, ['view', 'upload']],
    ['new', 0, ['view', 'create', 'upload']],
    ['race', 0, ['view', 'create', 'view', 'upload']],
    ['unavailable', 3, ['view', 'create', 'view']],
    ['upload-fails', 7, ['view', 'upload']],
  ]) {
    test(`${kind}: ${scenario} preserves upload behavior and exit status`, (t) => {
      const result = upload(t, kind, scenario)
      assert.equal(result.status, status, result.stderr)
      assert.deepEqual(result.calls.map((call) => call[1]), verbs)
      for (const call of result.calls) assert.equal(call[2], '1.6.8')
    })
  }
  for (const [event, overwrite, status] of [
    ['push', false, 1],
    ['push', true, 1],
    ['workflow_dispatch', false, 1],
    ['workflow_dispatch', true, 0],
  ]) {
    test(`${kind}: duplicate assets, ${event}, overwrite=${overwrite}`, (t) => {
      const result = upload(t, kind, 'duplicate', { event, overwrite })
      assert.equal(result.status, status, result.stderr)
      const files = kind === 'sdk' ? sdkFiles.map((file) => 'build/' + file)
        : [runtimeName('1.6.8'), runtimeName('1.6.8') + '.sha256'].map((file) => 'assets/' + file)
      assert.deepEqual(result.calls.at(-1), ['release', 'upload', '1.6.8', ...files,
        ...(status === 0 ? ['--clobber'] : [])])
    })
  }
  test(`${kind}: manual alpha publication marks a new Release as prerelease`, (t) => {
    const result = upload(t, kind, 'new', { event: 'workflow_dispatch', tag: '1.6.8-alpha.7' })
    assert.equal(result.status, 0, result.stderr)
    const creation = result.calls.find((call) => call[1] === 'create')
    assert.ok(creation.includes('--prerelease'))
    assert.ok(creation.includes('--verify-tag'))
    assert.equal(result.calls.at(-1)[2], '1.6.8-alpha.7')
  })
}

test('SDK asset presets and custom selections retain their exact upload targets', (t) => {
  for (const [preset, expected] of [
    ['static', sdkFiles.slice(0, 5)],
    ['dynamic', sdkFiles.slice(5)],
    ['core', [sdkFiles[0], sdkFiles[1], sdkFiles[5], sdkFiles[6]]],
    ['session-replay', [sdkFiles[2], sdkFiles[7]]],
    ['extension', [sdkFiles[3], sdkFiles[4]]],
    ['custom', [sdkFiles[0], sdkFiles[7]]],
  ]) {
    const result = upload(t, 'sdk', 'existing', {
      preset, event: 'workflow_dispatch', assetNames: ` ${sdkFiles[0]}, ${sdkFiles[7]} `,
    })
    assert.equal(result.status, 0, result.stderr)
    assert.deepEqual(result.calls.at(-1), ['release', 'upload', '1.6.8', ...expected.map((file) => 'build/' + file)])
  }
})

test('SDK custom selection rejects Electron assets before calling GitHub', (t) => {
  const result = upload(t, 'sdk', 'existing', {
    event: 'workflow_dispatch', preset: 'custom', assetNames: runtimeName('1.6.8'), overwrite: true,
  })
  assert.equal(result.status, 1)
  assert.match(result.stderr, /Unsupported asset name/u)
  assert.deepEqual(result.calls, [])
})

for (const [event, tag, expectedSDK] of [
  ['push', '1.6.8-alpha.7', false],
  ['push', '1.6.8-ALPHA.7', false],
  ['push', '1.6.8-beta.1', false],
  ['push', '1.6.8-BeTa.1', false],
  ['push', '1.6.8-rc.1', true],
  ['push', '1.6.8', true],
  ['workflow_dispatch', '1.6.8-alpha.7', true],
  ['workflow_dispatch', '1.6.8-beta.1', true],
  ['workflow_dispatch', '1.6.8-rc.1', true],
  ['workflow_dispatch', '1.6.8', true],
]) {
  test(`publication policy: ${event} ${tag} => electron=true, sdk=${expectedSDK}`, (t) => {
    const values = context(event, tag)
    const electronEnabled = electron.jobs.build.if === undefined ? true : evaluate(electron.jobs.build.if, values)
    assert.equal(electronEnabled, true)
    const options = resolveSDKOptions(temporaryDirectory(t), values)
    assert.equal(options.SHOULD_PUBLISH, String(expectedSDK))
  })
}

test('workflows publish disjoint assets and create a shared Release with identical metadata', (t) => {
  const sdkResult = upload(t, 'sdk', 'new')
  const electronResult = upload(t, 'electron', 'new')
  assert.equal(sdkResult.status, 0, sdkResult.stderr)
  assert.equal(electronResult.status, 0, electronResult.stderr)

  const sdkCreation = sdkResult.calls.find((call) => call[1] === 'create')
  const electronCreation = electronResult.calls.find((call) => call[1] === 'create')
  const option = (call, name) => call[call.indexOf(name) + 1]
  assert.equal(option(sdkCreation, '--title'), option(electronCreation, '--title'))
  assert.equal(option(sdkCreation, '--notes'), option(electronCreation, '--notes'))
  assert.ok(sdkCreation.includes('--verify-tag'))
  assert.ok(electronCreation.includes('--verify-tag'))

  const uploadedNames = (result) => result.calls.at(-1).slice(3)
    .filter((argument) => !argument.startsWith('--'))
    .map((file) => path.basename(file))
  const sdkNames = new Set(uploadedNames(sdkResult))
  assert.deepEqual(uploadedNames(electronResult).filter((name) => sdkNames.has(name)), [])
})

test('workflow inputs, dependencies and artifact wiring retain verification gates', () => {
  assert.deepEqual(electron.on.push.tags, ['[0-9]*'])
  assert.equal(electron.on.workflow_dispatch.inputs.tag.required, true)
  assert.equal(electron.on.workflow_dispatch.inputs.overwrite?.type, 'boolean')
  assert.equal(electron.on.workflow_dispatch.inputs.overwrite?.default, false)
  assert.equal(sdk.on.workflow_dispatch.inputs.overwrite.default, false)
  assert.equal(electron.jobs.verify.needs, 'build')
  assert.deepEqual(electron.jobs.publish.needs, ['build', 'verify'])
  for (const job of [electron.jobs.verify, electron.jobs.publish]) {
    assert.equal(job.if, undefined) // Default success dependency: skip after failed/skipped build or verification.
    assert.equal(job['continue-on-error'], undefined)
  }
  assert.equal(sdkJob.needs, undefined)
  assert.equal(sdk.concurrency, undefined)
  assert.equal(electron.concurrency['cancel-in-progress'], false)
  for (const step of sdkJob.steps.slice(2)) {
    assert.equal(step.if, "env.SHOULD_PUBLISH == 'true'")
  }
  assert.deepEqual(electron.jobs.verify.strategy.matrix.include, [
    { runner: 'macos-15', architecture: 'arm64' },
    { runner: 'macos-15-intel', architecture: 'x64' },
  ])
  const build = electron.jobs.build.steps
  assert.equal(build.find((step) => step.uses?.startsWith('actions/checkout@')).with.ref, '${{ inputs.tag || github.ref }}')
  assert.equal(build.find((step) => step.name === 'Build and package Universal managed runtime').run,
    'node scripts/build-electron-runtime.mjs --version "$SDK_TAG"')
  const artifact = build.find((step) => step.uses?.startsWith('actions/upload-artifact@')).with.name
  for (const job of [electron.jobs.verify, electron.jobs.publish]) {
    assert.equal(job.steps.find((step) => step.uses?.startsWith('actions/download-artifact@')).with.name, artifact)
  }
  const verification = electron.jobs.verify.steps.find((step) => step.name === 'Verify Universal runtime in Node and Electron').run
  assert.match(verification, /shasum -a 256 -c/u)
  assert.match(verification, /node scripts\/verify-electron-runtime\.mjs/u)
  assert.match(verification, /ELECTRON_RUN_AS_NODE=1[\s\S]*scripts\/verify-electron-runtime\.mjs/u)
})

test('release checkout still accepts tag prefixes and rejects a different commit', (t) => {
  const step = electron.jobs.build.steps.find((item) => item.id === 'release')
  const directory = temporaryDirectory(t)
  const output = path.join(directory, 'github-output')
  const mockGit = `
git() {
  case "$1" in
    check-ref-format) command git "$@" ;;
    rev-parse)
      if [[ "$2" == HEAD ]]; then printf '%s\\n' commit-a;
      elif [[ "$2" == 'refs/tags/1.6.8-alpha.7^{commit}' ]]; then printf '%s\\n' "$TEST_TAG_COMMIT";
      else return 1; fi ;;
    *) return 99 ;;
  esac
}
`
  for (const tag of ['1.6.8-alpha.7', 'refs/tags/1.6.8-alpha.7']) {
    const result = spawnSync('/bin/bash', ['-c', mockGit + step.run], {
      encoding: 'utf8', env: { PATH: process.env.PATH, RAW_TAG: tag, TEST_TAG_COMMIT: 'commit-a', GITHUB_OUTPUT: output },
    })
    assert.equal(result.status, 0, result.stderr)
  }
  assert.equal(fs.readFileSync(output, 'utf8'), 'tag=1.6.8-alpha.7\ntag=1.6.8-alpha.7\n')
  const result = spawnSync('/bin/bash', ['-c', mockGit + step.run], {
    encoding: 'utf8', env: { PATH: process.env.PATH, RAW_TAG: '1.6.8-alpha.7', TEST_TAG_COMMIT: 'commit-b', GITHUB_OUTPUT: output },
  })
  assert.notEqual(result.status, 0)
  assert.equal(fs.readFileSync(output, 'utf8'), 'tag=1.6.8-alpha.7\ntag=1.6.8-alpha.7\n')
})

test('all workflow shell steps parse with bash', () => {
  for (const workflow of [sdk, electron]) {
    for (const job of Object.values(workflow.jobs)) {
      for (const step of job.steps) {
        if (!step.run) continue
        const result = spawnSync('/bin/bash', ['-n'], { input: step.run, encoding: 'utf8' })
        assert.equal(result.status, 0, `${workflow.name}: ${step.name}: ${result.stderr}`)
      }
    }
  }
})
