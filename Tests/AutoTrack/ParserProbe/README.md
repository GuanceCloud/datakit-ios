# Shared-parser regression for issue 7159405221

This App-hosted XCTest adapts the reduced model attached to Feishu issue 7159405221.
`FTSharedParserFixture.m` preserves that attachment's Classic/Minimal controller
initializers and shared parser. It is not the customer's full TUIKit project.

The fixture lives in the App image. The test legitimately initializes Classic,
then starts the real SDK through its public APIs with automatic Views enabled.
Loading-time collection and its exclusion list are left at their defaults. It
waits for the default App/Framework scan, without a sleep or custom image include.

Assertions independently require all of the following:

- Minimal remains uninitialized after the scan.
- The selected parser remains Classic.
- The same payload still renders `custom-link-cell`.
- Payload bytes are unchanged.
- Minimal is marked instrumented, proving that scanning and hook installation
  actually ran rather than silently skipping the fixture.

## Running

Prerequisites: Xcode, an existing iOS simulator, and Ruby with `xcodeproj`.
The generated host includes a Scene manifest for current simulator runtimes.

```sh
ruby scripts/testing/shared-parser-project.rb /tmp/FTSharedParserProbe
xcodebuild -project /tmp/FTSharedParserProbe/FTSharedParserProbe.xcodeproj \
  -scheme FTSharedParserProbe \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/ft-shared-parser-build \
  -parallel-testing-enabled NO -jobs 2 test
```

Each run must launch a fresh App process because Objective-C initializes each
class only once per process. Pass an alternate SDK checkout as the second
generator argument to run the same assertions against a baseline:

```sh
ruby scripts/testing/shared-parser-project.rb /tmp/FTSharedParserProbeBefore /path/to/baseline
```

The third argument selects SDK debug logging (`0`, the default, or `1`). This is
independent of Xcode's Debug/Release build configuration. Both log settings should
preserve the parser on the fixed SDK. A baseline containing the original bug is
expected to fail the unchanged correct-behavior assertions and emit
`minimal_initialized=true`, `selected_parser=FTProbeMinimalController`, and
`render=unsupported-message` in its `FT_PARSER_REGRESSION` JSON record.

No messaging server, customer credentials, or external intake is needed; automatic
upload is disabled. The test does not verify the full customer's IM integration,
WebSocket transport, or unrelated HTTP/Trace behavior.

## Baseline and evidence boundary

The unchanged assertions reproduce the original defect against develop commit
`84c9150bc09f7759abb527a28523fe841a5a53ab`. The fixed implementation preserves the
Classic parser with default loading-time settings and SDK debug logging either
off or on. These are reduced-model regressions, not a full customer project run.

Keep machine-specific results, logs, source hashes and result bundles outside
version control. The committed fixture and generators are the reproducible inputs.
