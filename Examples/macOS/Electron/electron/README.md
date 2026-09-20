# OrbitDesk — Electron-owned managed mode

This is a pure Electron application. Every visible page is rendered by Electron, while the Electron Main process owns and initializes the Guance macOS Native SDK through the Adapter's `managed` mode.

The integration points are:

- `electron/main.cjs`: maps environment variables to the shared `native.settings` object and calls `bootstrap()` with `native.mode: "managed"`.
- `electron/preload.cjs`: installs the Adapter's Browser SDK bridge alongside the example's own IPC API.
- `src/`: initializes Browser RUM and Browser Logs with bridge-only defaults, displays the non-sensitive Native settings received from Main, and exercises views, actions, resources, errors, logs, Session Replay, and an auxiliary `BrowserWindow`.

Renderer events are forwarded to the Native SDK through the bridge. Native upload configuration remains owned by `native.settings`; Browser RUM and Browser Logs do not need a separate intake endpoint for this transport. Browser Logs starts only when the Adapter reports the `log` capability, which requires `GUANCE_NATIVE_LOGGING=true`.

Follow the [workspace prerequisites](../README.md#prerequisites), then run from this directory. Fill in `.env.local` with a Native RUM application ID and a DataKit endpoint, or a DataWay endpoint and client token, before starting the application:

```sh
cp .env.example .env.local
npm install
npx guance-electron-native --sdk-version <version>
npm run dev
```

Native lifecycle and launch Actions remain under the Apple SDK's internal
automatic collection; the Adapter does not expose or override its Action
tracking setting and the example does not synthesize launch data through a
custom Action API. Sampling values under `GUANCE_NATIVE_*_SAMPLE_RATE` use the
Adapter's cross-platform `0..1` public units.

Replace `<version>` with the Native SDK version to install. The CLI downloads the universal runtime into `.cloudcare/native/darwin/runtime`; the version is required and there is no `managed` subcommand. No Xcode installation or local Native SDK checkout is required when a matching published runtime is available. For an unpublished version, add `--runtime-archive /path/to/runtime.tar.gz` with its matching `.sha256` sidecar; the version must match the archive manifest.

For a packaged development build:

```sh
npm run package:dir
```

Packaging copies the generated Guance Native runtime to `Contents/Resources/native`. No AppKit UI component or separate Native host is included in this example.
