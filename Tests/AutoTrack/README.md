# View controller scan initialization regression

The separate [App-hosted shared-parser regression](ParserProbe/README.md) covers
the original issue's unchanged-payload/overwritten-parser business symptom through
public SDK startup and the default image scan.

The hostless XCTest target links this checkout's real `GuanceSDK` SwiftPM product.
It tests unused Objective-C controller classes, without requiring a customer project.

```sh
ruby scripts/testing/view-controller-initialization-project.rb /tmp/FTViewControllerInitialization
xcodebuild -project /tmp/FTViewControllerInitialization/FTViewControllerInitialization.xcodeproj \
  -scheme FTViewControllerInitialization \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/ft-vc-initialization-build test
```

Prerequisites: Xcode, an available iOS simulator, and Ruby with `xcodeproj`.

The test asserts exact `+initialize` counts: zero after candidate filtering and two
complete asynchronous image scans, then one after deliberate instance creation.
It also verifies that normal parent/child controllers receive lifecycle hooks,
while a navigation-controller subclass remains excluded. Runtime image paths keep
the scan independent of filesystem symlink aliases. The test bundle specifies its
principal class to prevent `NSBundle` from choosing a fixture during bundle loading.

The original scan path could initialize a candidate: sending `+isSubclassOfClass:` in
the blacklist check, asking `+[NSBundle bundleForClass:]` for the SwiftUI check
(which can enter runtime method resolution), followed by the swizzle macro's
`[classToSwizzle class]` during hook installation. Candidate scanning now excludes
system images before checking the blacklist, without a separate SwiftUI check.
The default page filter and SwiftUI loading-time logic retain their SwiftUI checks
using runtime image metadata. The macros pass their Class argument directly.
The swizzler also avoids ARC
retains of target Class objects in associated-object helpers and block captures.
A separate macro regression
checks that instance/class replacements still call the originals and return exact
expected values without initializing the target during installation.

This is a regression for SDK page scanning side effects. It does not establish
that a complete customer TUIKit project or its message parsing has been reproduced.

## Loading-time controls

`FTViewLoadingTimeConfigurationTests` covers the public loading-time switch and
`viewLoadingTimeClassNameExcludes` (exact, case-sensitive runtime controller class
names, without inheritance matching or custom page-name matching). Tests verify
defaults, defensive copies, dictionary round trips,
filtering before instrumentation, inherited parent hooks, repeated appearances,
modal restoration and preservation of automatic View start/stop events. Disabled
or excluded durations retain the existing unavailable value of `-1`, including
restored Views; an enabled controller is checked against an exact 5,000,000 ns
duration with a controlled clock. The suite also checks SwiftUI switch/bridge
behavior and rescanning after a new startup configuration removes an exclusion.

Automatic loading-time collection requires both `enableTraceUserView` and
`enableTraceUserViewLoadingTime`. Turning automatic View tracking off or shutting
down the collector disables timing in hooks that were installed earlier; it does
not uninstall those hooks. The configured loading-time preference is retained,
so automatic View tracking can later be reenabled without changing that option.
The legacy internal startup path obeys the same policy. Explicit SwiftUI View
notifications retain their View events but do not carry automatically collected
loading time while automatic View tracking is off.

Controlled-clock regressions first install hooks and collect exactly 5,000,000 ns,
then assert zero clock reads and no automatic View events while tracking is off.
After reenablement, existing hooks report exactly 5,000,000 ns for a fresh load.
The startup matrix also verifies that disabling only loading time keeps the
automatic View handlers and does not launch loading-time scans.

Configure these options before starting RUM:

```objc
rumConfig.enableTraceUserView = YES;
rumConfig.enableTraceUserViewLoadingTime = YES;
rumConfig.viewLoadingTimeClassNameExcludes = [NSSet setWithObjects:@"TUIChatViewController", @"TUIConversationViewController", nil];
```

Set `enableTraceUserViewLoadingTime = NO` to disable automatic loading-time collection
for all pages. The options do not remove hooks already installed; inherited hooks
honor the policy at callback time. Controllers must call `super` in lifecycle
overrides for the base-class automatic View tracking to receive those callbacks.
