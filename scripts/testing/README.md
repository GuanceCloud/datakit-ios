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
