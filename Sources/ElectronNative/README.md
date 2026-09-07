# Electron Native Runtime Source

This directory owns the Apple Native source used by the Electron managed
runtime. It is intentionally part of the Native SDK rather than an npm package.

## Layout

- `Bridge` exposes a stable C ABI over the Guance Apple SDK. The root
  `Package.swift` builds it as the dynamic `GuanceElectronNative` product.
- `NodeAddon/guance_electron.mm` maps Node-API calls to the C ABI. It is not a
  SwiftPM source because it must compile against the Node headers selected by
  the consuming Electron environment.

The Electron Adapter npm package fetches an immutable revision of this
repository, builds `GuanceElectronNative`, and compiles the addon source. The
Adapter does not copy or maintain these Native sources.

From this repository, verify the dynamic product with:

```sh
swift build --product GuanceElectronNative
swift test --filter GuanceElectronNativeTests
```
