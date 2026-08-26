# Guance Electron distributions

This directory builds two macOS Electron delivery flavors from the same Native
SDK checkout and version:

| Package | Ownership mode | Contents |
|---|---|---|
| `@cloudcare/guance-electron-adapter` | Native-owned Mixed Mode | JavaScript Main adapter and preload only |
| `@cloudcare/guance-electron-macos` | Electron-owned Full Mode | Full Native APIs, embedded Adapter, Node Addon, Objective-C dylib, and resources |

Install dependencies and run JavaScript tests:

```sh
npm install
npm test
```

Build Universal Native artifacts and both local npm packages:

```sh
npm version <sdk-version> --workspaces --include-workspace-root --no-git-tag-version
npm run release
```

Release artifacts are written to `release/npm/`. They are generated from the
current Native SDK checkout and should be attached to the matching SDK release,
not committed to Git. Packaging fails if the workspace, Adapter, and Full Mode
versions do not match.

Customers install only the artifact for their ownership mode:

```sh
# Native-owned Mixed Mode
npm install ./vendor/cloudcare-guance-electron-adapter-<sdk-version>.tgz

# Electron-owned Full Mode
npm install ./vendor/cloudcare-guance-electron-macos-<sdk-version>.tgz
```
