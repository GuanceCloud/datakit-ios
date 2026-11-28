# LC-001 lifecycle regression tests

Routine lifecycle regressions belong to the existing `FTMobileSDKUnitTests` XCTest target. `FTResourceLifecycleTest` is compiled from `Examples/iOS/Tests/FTMobileSDKUnitTests/Resource/FTResourceInstrumentTest.m` and reuses its Resource receiver fixture. Its setup is independent of the original `FTResourceInstrumentTest` class and does not require backend credentials.

## XCTest coverage

The ten unit tests cover:

- Both WebSocket error-filter return values, with and without reentrant public SDK shutdown: exact filter/provider/Resource counts, failed-handshake state, filtered error, provider properties, a 500 ms missing-metrics fallback, and duplicate terminal callbacks.
- Public shutdown called twice inside a provider on the interceptor queue, discarding the unfinished Resource.
- Context API reentry without shutdown and shutdown after Resource completion, each with exactly one normal settlement.
- Late manual/automatic callbacks, repeated SDK/instrumentation shutdown, non-creating getters, and unchanged request passthrough.
- Restart ownership without a blocked provider: old callbacks, old task admission and repeated old-instance stop cannot affect the new collector; only the new Resource settles into the new receiver/context.
- Disabled instrumentation with a stubbed URLSession request: the application completion runs once and no Resource/provider callbacks run.

Run from the repository root, selecting an available simulator UUID:

```bash
pod install --deployment
xcrun simctl list devices available
xcodebuild test -workspace FTSDK.xcworkspace \
  -scheme FTMobileSDKUnitTestsForCmd \
  -only-testing:FTMobileSDKUnitTests/FTResourceLifecycleTest \
  -destination 'platform=iOS Simulator,id=<simulator-uuid>' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

The unit cases use explicit collector admission, queue ordering and XCTest expectations. They do not block a provider while another thread enters shutdown. No global marker counters or external watchdog are needed. The late-callback case observes initializer calls locally and restores the original implementation in `@finally`, so even a temporary collector created and detached by repeated stop fails the test. Expectations bound a failed test; exact state/count assertions establish correctness.

## Retained subprocess probe

`FTSDKShutdownDeadlockProbe.m` retains only these four schedules:

| Case | Why process isolation is required |
|---|---|
| `primary` | Real automatic URLSession collection enters an application provider; main-thread SDK shutdown overlaps its Context API reentry. A regression can permanently block main and the collector queue. |
| `no-reentry` | Keeps the same automatic-collection overlap and provider gate as primary, removing only Context reentry. This is the paired control for the original wait cycle. |
| `blocked-provider` | The provider gate stays closed until main-thread shutdown returns. A synchronous drain regression prevents test cleanup from releasing that gate. |
| `restart` | Extends the blocked-provider schedule with immediate restart, old callbacks/repeated stop, and a real new automatic request before verifying old/new Resource and Context ownership. |

These schedules must not run inside the ordinary XCTest host: an SDK regression can block the host or leave a permanently blocked worker even after an expectation times out. The external runner owns the disposable App process and terminates it after collecting explicit markers. Timeouts only isolate hangs, not prove correctness. This preserves the original real automatic capture/reentry boundary in addition to unit-level coverage.

Use a new output directory and build the current source before running:

```bash
LC001_WORK_DIR="$(mktemp -d /tmp/lc001.XXXXXX)"
LC001_DEVICE="<simulator-uuid>"
ruby scripts/testing/sdk-shutdown-deadlock-project.rb "$LC001_WORK_DIR/project"
xcodebuild -project "$LC001_WORK_DIR/project/FTSDKShutdownDeadlockProbe.xcodeproj" \
  -scheme FTSDKShutdownDeadlockProbe -configuration Debug -sdk iphonesimulator \
  -destination "platform=iOS Simulator,id=$LC001_DEVICE" \
  -derivedDataPath "$LC001_WORK_DIR/DerivedData" build
python3 scripts/testing/lc-001-fixed-runner.py \
  --device "$LC001_DEVICE" --output "$LC001_WORK_DIR/results" \
  --app "$LC001_WORK_DIR/DerivedData/Build/Products/Debug-iphonesimulator/FTSDKShutdownDeadlockProbe.app"
```

The runner defaults to all four retained cases. `--cases` accepts only these names. The former `no-overlap`, `no-shutdown`, `stop-on-interceptor`, `instrumentation-off`, `late-callbacks`, and four `ws-filter-*` modes now run as unit tests. Historical thirteen-case results and original failure evidence remain unchanged; they describe the previous fixture layout.
