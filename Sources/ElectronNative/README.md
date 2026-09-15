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

The publish-electron-runtime.yml workflow currently runs for every pushed SDK
version tag beginning with a digit, including prerelease and stable tags, and also
supports manual dispatch for an existing tag. This broad automatic trigger is
intentional during integration and can be narrowed when the release policy is
finalized. The workflow checks that the tag matches the SDK version and verifies
the same Universal runtime on arm64 and x86_64 in Node.js and the minimum supported
Electron 22 before uploading the archive and SHA-256 sidecar to the matching GitHub
Release.

SDK assets and Electron runtime assets have independent workflows. The SDK asset
workflow continues to skip automatic alpha/beta publishing while allowing manual
publishing. A failed Electron build or verification does not block the SDK
workflow. Their asset filenames are disjoint, and both use the same Release title,
notes, and prerelease rule. If both workflows try to create the same Release
concurrently, the losing workflow checks that the Release now exists before
continuing to upload its own assets. Permission, network, and upload errors still
fail the affected workflow.

For manual publishing, the workflow must first exist on the default branch for
GitHub to show the Run workflow entry. Select a branch containing the updated
workflow, then enter the target SDK tag. That tag must contain the corresponding
build and verification scripts; the selected branch supplies the workflow, while
the target tag supplies the source and scripts. See GitHub's
[workflow_dispatch requirements](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch).

The Electron overwrite input defaults to false. Existing same-name assets cause
an upload failure by default. Only manual dispatch with overwrite explicitly set
to true uses --clobber to replace the runtime archive and its SHA-256 sidecar for
that version; it never overwrites SDK assets. Automatic publishing does not
overwrite assets. The SDK workflow retains its own asset selection and overwrite
options.

Install a published runtime with the adapter CLI, specifying the SDK version:

    guance-electron-native --sdk-version <version>

The command downloads the selected Universal release asset, checks the archive
and manifest, and installs it in the customer's application. It has no
architecture option and never falls back to compiling SDK source. Customers
package the entire runtime outside ASAR and sign the addon with the application.
