# AI Agents Guide for ft-sdk-ios

## SDK Design

- Protect host applications. SDK collection failures must degrade gracefully. Keep synchronous disk and network I/O off the main thread.
- Document queue ownership. Snapshot mutable state before crossing queues. Keep shutdown nonblocking and prevent stale work from affecting a restarted instance.
- Use typed protocols for calls to a specific module and publish events for state changes. Document delivery queues and receiver lifecycles.
- Capture timestamps at the event boundary. Build SDK diagnostics from known-safe fields such as error categories and codes. Exclude raw errors, credentials, and customer payloads.

## API and Bridge Compatibility

- Keep public API, cross-module interfaces, and module-local implementation separate. Export only headers and symbols intended for consumers.
- Preserve public symbols, imports, defaults, and behavior. Treat interfaces used by downstream bridges as compatibility-sensitive regardless of visibility. Search call sites, bridges, target declarations, and umbrella headers before making changes. Deprecate public APIs before removal.
- Check affected imports, signatures, and behavior from Objective-C, Swift, and bridge consumers as applicable. Keep platform availability and distribution metadata aligned.
- The minimum deployment targets are iOS 15.0, tvOS 15.0, and macOS 12.0 for products that support those platforms. Guard APIs introduced in newer OS versions.

## Swizzling and Auto-Instrumentation

- Assume another SDK can hook the same selector before or after ours. Preserve the existing implementation chain, method signature, return value, and host callback order. Avoid duplicate installation, reentrant collection, and instrumentation of SDK-owned traffic.
- For affected hooks, verify both installation orders and reentry through Objective-C dispatch. If a delegate proxy is involved, also verify the visible delegate identity, forwarding, and weak-reference lifetime.

## Verification

| Change | Minimum verification |
| --- | --- |
| Documentation only | Review the edited text and verify links and command references. |
| Behavior or bug fix | Run focused tests for the affected behavior. Use deterministic scheduling and test data without live credentials. |
| Platform-specific or shared code | Build for all affected supported platforms, run the relevant tests, and report any coverage gaps. |
| Public API or bridge | Verify affected consumer imports, builds, and behavior. Run checks for all affected distribution methods. |
| Package or distribution | Run the affected package checks. |

Run `bash scripts/verify-distribution-packages.sh` without `--only` when shared public APIs or package structure change. To check a single distribution method, use `--only spm`, `--only cocoapods`, or `--only framework`.

Derive test expectations from intended behavior and assert exact values for metrics. For bug fixes, confirm that the same test fails for the expected reason before the fix and passes afterward. Report which checks ran and any gaps.
