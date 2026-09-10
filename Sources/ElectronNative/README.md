# Electron Managed Runtime

The Native SDK owns the bridge, Node-API addon source, build tooling, and
precompiled Electron managed runtime. Customers do not compile Native code.

This runtime is **only for full (managed) mode**. In mixed (external) mode,
the Native host supplies the SDK and bridge. The adapter communicates with that
host and must not load this runtime or introduce a second copy of the SDK.

## Build and package

From the Native SDK repository root, on a Mac with Swift, Clang, the macOS SDK,
and Node.js 22 or newer:

    node scripts/build-electron-runtime.mjs

The --version option checks that the release tag matches GuanceSDK.podspec.
The --debug option builds a development runtime without release archives.
GUANCE_ELECTRON_NODE_HEADERS can point to the directory containing node_api.h
when the Node installation does not include headers in its usual location.

The build statically links GuanceElectronNative into the Node-API 8 addon and
retains Objective-C categories with -Wl,-ObjC. SDK source remains in Bridge
and NodeAddon; no Native SDK source or compiler is needed in the npm adapter.

Outputs are under build/electron-native:

    guance-electron-runtime-<version>-darwin-universal.tar.gz
    guance-electron-runtime-<version>-darwin-universal.tar.gz.sha256

Each archive contains:

    runtime/
      guance_electron.node
      GuanceSDK__GuanceSDKCore.bundle/
      runtime-manifest.json

The manifest records the Native SDK version and revision (when available),
architectures (arm64 / x86_64), minimum macOS version, Node-API version,
static linkage, build configuration, and SHA-256 of every runtime file.
The minimum macOS value describes the Native binary; the selected Electron
version may have a higher minimum.

## Verification and publishing

    node --test scripts/electron/*.test.mjs
    node scripts/verify-electron-runtime.mjs build/electron-native/universal/runtime

Verification checks architecture slices, signatures, resource bundles, static
linkage, Objective-C categories, developer paths, file hashes, and exported
Node-API methods. Loading runs only on a matching host architecture.

The publish-electron-runtime.yml workflow builds on SDK tags (including
prereleases), checks the same Universal runtime on arm64 and x86_64 in Node.js
and the minimum supported Electron 22, and uploads that archive and checksum sidecar to the matching
GitHub Release. It can also be dispatched for an existing tag. Existing release
assets are not overwritten.

The adapter's ft-electron-native managed command downloads the pinned Universal
release asset, checks the archive and manifest, and installs it in the
customer's application. It has no architecture option and never falls back to
compiling SDK source. Customers package the entire runtime outside ASAR and sign
the addon with the application.
