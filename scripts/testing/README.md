# Focused View Timing Metric Tests

The hostless XCTest project links the checkout's SwiftPM `GuanceSDK` product. It avoids demo app extensions and third-party test dependencies.

Prerequisites: Xcode, an available iOS simulator, and Ruby with `xcodeproj`.

```sh
ruby scripts/testing/view-timing-metrics-project.rb /tmp/FTViewTimingMetrics
xcodebuild -project /tmp/FTViewTimingMetrics/FTViewTimingMetrics.xcodeproj \
  -scheme FTViewTimingMetrics \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/ft-view-metrics-focused test
```

The same test file is registered in the existing iOS/tvOS unit-test targets. Tests inject exact event timestamps, replaceable internal INV/TNS predicates, collector clocks and queues. They cover actual writer filtering and serialization in addition to numeric lifecycle results. No external endpoint or sleep is required. The suite covers shared Resource/TNS intervals, completed batches, optional URL reclassification, View-origin changes, pure metric reads and full View replacement snapshots.

# Focused Replay Current-Context Tests

Generate a hostless test project linked against this checkout's real `GuanceSDK` and `GuanceSessionReplay` products:

```sh
ruby scripts/testing/replay-current-context-project.rb /tmp/FTReplayCurrentContext-ios ios
xcrun simctl list devices available
xcodebuild test -project /tmp/FTReplayCurrentContext-ios/FTReplayCurrentContext.xcodeproj \
  -scheme FTReplayCurrentContext -destination 'platform=iOS Simulator,id=<available-device-id>'
ruby scripts/testing/replay-current-context-project.rb /tmp/FTReplayCurrentContext-macos osx
xcodebuild test -project /tmp/FTReplayCurrentContext-macos/FTReplayCurrentContext.xcodeproj \
  -scheme FTReplayCurrentContext -destination 'platform=macOS'
```

Use a Ruby environment containing `xcodeproj`. The shared suites cover existing-View delayed startup with exact capture IDs, inactive retained Views, empty context, duplicate starts and sampling, missing bindings, delayed RUM/message-bus/scheduler work, Core memory callbacks while rumQueue is blocked, FIFO reads/updates, source replacement, shutdown/rebuild and external-recorder ownership. Queue barriers and explicit scheduler capture replace timing sleeps. No test endpoint is required.
# Early Crash Upload Tests

`Examples/iOS/Tests/FTMobileSDKUnitTests/Network/FTEarlyCrashUploadTests.m`
is registered in the existing `FTMobileSDKUnitTests` target. Run it through the
normal iOS unit-test scheme. It covers the five-second boundary, missing event
and SDK-start times, invalid/truncated markers, I/O failure, repeated reads and
initialization, identical duplicate markers, and simulated multi-launch recovery.
Upload tests use deterministic scheduling and retry probes for exact deadlines,
cache deletion/retention, automatic-upload gating, cancellation and manual upload
without real waits.

History recovery and current-launch recording preparation run independently on
`com.ft.early-crash`. The SDK entry captures only the original monotonic start.
Upload-manager initialization restores and consumes history even when automatic
upload or Crash collection is disabled, without creating a recording file. Crash
setup enables recording and prepares its directory and descriptor; existing Crash
monitor installation remains synchronous. Both operations share the serial queue
so a later history lookup cannot delete the current launch's marker.
Crash handlers publish eligible occurrences through lock-free atomics and never
wait for preparation. Descriptor publication and pending-event handshakes allow
preparation to persist an occurrence captured before the file was opened. If the
process exits before that open completes, persistence cannot be guaranteed.

Automatic upload reservations wait asynchronously for history recovery and deduct its
elapsed time from the original two/ten-second deadline. Canceled or invalidated
reservations do not consume the allowance while waiting. Manual uploads retain
their existing path. Regression cases block the preparation queue during real
SDK startup, inject delayed completion before/after the upload deadline, and
exercise manual upload/shutdown while preparation is pending. The C suite also
checks delayed events against the original start and races descriptor publication
with crash recording across 100 isolated launch states.

The C integration tests retain the cases requiring separate processes. Seven
`fork`/`exec` launches verify persistence and consumption across actual process
restarts. Four writer-exit cases pause or interrupt the first write, inject a
partial first write, or partially repeat a completed write. They terminate the
writer without cleanup and assert a two-second wait in the recovering process.
The macOS host also verifies that the iOS-only global policy remains disabled.
These tests need only Xcode command-line tools:

```sh
bash scripts/testing/early-crash-policy.sh
```
