# macOS Electron examples

These full OrbitDesk applications demonstrate both Native SDK ownership models while preserving their existing UI, interactions, and Native Host.

| Directory | Adapter mode | Native SDK owner |
| --- | --- | --- |
| [`electron/`](electron/README.md) | `managed` | Electron Main |
| [`native/`](native/README.md) | `external` | Swift AppKit host |

## Prerequisites

- macOS 13 or newer
- Node.js 22.12 or newer
- GitHub access to download the managed-mode Native runtime
- A sibling `ft-sdk-electron-native-adapter` checkout

Managed mode downloads a precompiled universal runtime and does not require Xcode. External mode additionally requires Xcode with Swift 5.9 or newer and the macOS SDK because its Swift host uses a local SwiftPM dependency on the containing checkout through `native/macos/Package.swift`.

The Adapter npm package is still private and versioned `0.0.0-local`. Both examples therefore use a relative file dependency on a sibling Adapter checkout:

```text
work/
├── ft-sdk-ios/                         # Any checkout name is supported
│   └── Examples/macOS/Electron/
│       ├── electron/
│       └── native/
└── ft-sdk-electron-native-adapter/
```

Use an Adapter revision containing the `ft-electron-native` CLI and its `.cloudcare` output layout. Each application's `package.json` and lockfile use `file:../../../../../ft-sdk-electron-native-adapter`. A published Adapter dependency can replace this when an npm release is available.

## Electron-owned managed mode

From this example workspace:

```sh
cd electron
cp .env.example .env.local
npm install
npx ft-electron-native managed
npm run dev
```

Before interactive startup, fill in `.env.local` with a Native RUM application ID and a DataKit endpoint, or a DataWay endpoint and client token. The runtime command downloads universal `arm64` and `x86_64` output into `.cloudcare/native/darwin/runtime`. A matching published runtime does not require Xcode or `GUANCE_NATIVE_SDK_ROOT`.

Electron owns Native SDK startup through `bootstrap()` and `native.settings`. `npm run package:dir` copies the generated runtime outside ASAR into `Contents/Resources/native`.

## Native-owned external mode

From this example workspace:

```sh
cd native
cp .env.example .env.local
npm install
npm run dev
```

Fill in the same Native intake fields before interactive startup. The Swift package resolves the containing checkout and links `GuanceSDK`, `GuanceElectronWebView`, and `GuanceSessionReplay`. The Native host initializes the SDK, RUM, and Logger, starts `FTElectronBridgeServer`, and injects socket credentials into its Electron child. Electron connects with `native.mode: "external"`. Both examples initialize `@cloudcare/browser-logs` in the Renderer when the bridge advertises Web Log support.

## Verification

After installing dependencies and downloading the managed runtime, run from this workspace:

```sh
npm --prefix electron run build:renderer
npm --prefix native run build:renderer
npm --prefix native run native:test
npm --prefix electron run smoke
npm --prefix native run smoke
```

The startup checks provide local placeholder intake settings when no values are configured, verify that the Adapter and Renderer become ready, and exit automatically. They verify startup and bridge connectivity; backend ingestion is not part of these checks.

If npm reports `ENOTFOUND`, retry with a one-command registry override:

```sh
npm_config_registry=https://registry.npmjs.org npm install
```

Electron 43 downloads its binary on first use. If that download is unavailable, an `ELECTRON_MIRROR` override on `npm run dev` or `npm run smoke` can select an accessible mirror. Application configuration, dependency caches, generated runtime files, and build output are ignored by Git.
