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

The same test file is registered in the existing iOS/tvOS unit-test targets. Tests inject exact event timestamps, explicit window-close commands, collector clocks and queues. They cover actual writer filtering and serialization in addition to numeric lifecycle results. No external endpoint or sleep is required.
