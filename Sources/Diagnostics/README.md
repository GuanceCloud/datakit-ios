# Optional SDK diagnostics

The independent `FTDiagnostics` API owns local diagnostic sessions. It does not
add options to FTSDKConfig, log diagnostic records through the business SDK, or
upload them. The core bridge is compiled with the existing BaseUtils target.

## Integration

CocoaPods: add `GuanceSDK/Diagnostics` beside the existing SDK subspecs, using the
same modified SDK version or local checkout. Swift Package Manager: select the
`GuanceDiagnostics` library product. The optional collector is not added to the
existing Xcode SDK framework targets; use CocoaPods/SPM for the component, or add
its sources explicitly when integrating SDK source by hand.

```objc
#import <GuanceSDK/FTDiagnostics.h> // CocoaPods; SPM module: GuanceDiagnostics
NSURL *root = /* private Application Support subdirectory unique to this process */;
FTDiagnostics *diagnostics = [[FTDiagnostics alloc]
    initWithDirectory:root config:[FTDiagnosticsConfig new] error:&error];
NSString *session = [diagnostics start:&error];
// Initialize/use SDK; explicitly drain business uploads if required.
NSDictionary *summary = [diagnostics stop:&error];
NSArray *page = [diagnostics records:session offset:0 limit:100 error:&error];
[diagnostics exportSession:session toDirectory:newExportDirectory error:&error];
[diagnostics close];
```

Use `sessions`, `summary:error:`, `status`, `deleteSession:error:`, and
`cleanExpired:` for management. Configuration is copied at initialization. Main
app and extensions must choose different directories; no shared App Group storage
or cross-process coordination is created automatically. Exclude the diagnostic
directory from backups according to your application's local-file policy.

## Apple hook coverage

- FTHTTPClient: a dedicated NSURLSession delegate collects completed transaction
  metrics. Request/response body counts use NSURLSessionTaskMetrics, including
  transactions in a redirect chain. Missing metrics remain unavailable. The
  delegate does not retain FTHTTPClient, and business completion semantics remain.
  A transport error is a failed attempt even when HTTP response headers were 2xx;
  the observed status code is preserved alongside `transport_error`.
- SQLite: single and transactional inserts; actual affected rows for upload,
  capacity, explicit and expiration cleanup; existing typed count queries.
  Write failures are marked by reason and are not proof of final event loss.
- Cache policy observes incoming Log/RUM rejection decisions.
- Upload worker: selected batches, oldest-event age, scheduled retries, and
  non-retryable response cleanup. A 4xx cleanup is not reported as HTTP success.
- Replay: append/write operations, batch selection/creation age, observed file
  backlog, expiration and deletion, retry scheduling, and shared HTTP uploads.
  Replay file-write bytes include the supplied storage framing and are not directly
  comparable with Android's pre-framing Replay write bytes. HTTP body counters
  have their separate transfer definition.
- This does not provide a process-wide network counter, per-event delivery tracing,
  or loss accounting before storage (such as all RUM sampling decisions).

## Verification

```sh
bash tools/diagnostics/test.sh
swift build --target GuanceDiagnostics
swift build --target GuanceSessionReplay
```

The Foundation test suite runs on macOS without a device and exercises lifecycle,
isolation, concurrent stop/completion, damaged checkpoints, retention, quotas and IO failure. A loopback fixture runs the actual
FTHTTPClient and verifies its request/response byte metrics. iOS simulator/device
integration and collector overhead are additional acceptance checks.

## Data contract (schema_version = 1)

Each session contains `summary.json` (an atomic checkpoint, updated approximately
once per second) and `events.jsonl` (bounded batch/upload diagnostic records).
Records use `session_id`, `event_type`, `channel`, and Unix `time_ms`. Upload start
and end records share a generated `attempt_id`; durations use a monotonic clock.
No endpoint, query string, headers, business payload, token, user identifier or
business event ID is exported. Channels are bounded: log, rum, replay, other.
The latter includes SDK control requests and storage operations without reliable
channel attribution. A diagnostic attempt is not a business-event delivery receipt.

Event types:

| Type | Meaning |
| --- | --- |
| storage_write | Completed storage writes; aggregate only, no per-event details |
| storage_remove | Observed storage cleanup, with a reason and actual count when available |
| discard | Observed filtering, write failure or non-retryable outcome; inspect reason rather than treating all observations as lost events |
| backlog | Successful existing storage count/read observation, not a new polling query |
| batch | Selected upload batch; repeated selections can include retries |
| retry | Scheduled retry or retained failed batch, not proof a retry reached the server |
| upload_start / upload_end | One SDK transport invocation and its observed outcome |

`summary.counters` is keyed by `channel.event_type.field`. Counts and byte/duration
values are summed; `.samples` counts observations with a valid value and `.max`
retains the maximum. Backlog is the latest value and includes `.observed_ms` for
freshness. `observations` and bounded `reason.*` counters count hook invocations,
not necessarily business events. Missing fields are unavailable, never implied zero.
Log/RUM backlog is in events; Replay backlog is in files and may precede age
eligibility checks. These are observations of shared business storage, and must
not be added across processes. No extra periodic scan of business storage is made.

Byte scopes are deliberately separate:

- `storage_write.bytes`: serialized payload bytes for Log/RUM; Replay uses its
  documented writer boundary. This is not SQLite/WAL/device IO volume.
- `request_body_bytes` / `response_body_bytes`: observed HTTP body bytes; consult
  `byte_source` and `byte_availability` for each attempt. Headers, TLS/TCP overhead,
  TCP retransmissions and radio traffic are excluded. Partial failed writes may
  be unobservable. Do not infer server receipt from stream writes.
- `batch.age_ms`: uses `age_source`; Log/RUM uses the oldest event timestamp,
  which is not enqueue time. Replay file age has a different source. Never compare
  these as if they were a common exact end-to-end delivery latency.

HTTP observations are attributed at completion; they are useful for totals and
whole-window averages, not true instantaneous bandwidth peaks. Automatic transport
redirects/retries can be folded into one attempt; SDK-scheduled retries are separate.
A snapshot cannot reconstruct a complete per-event lifecycle or prove zero data loss.

## Lifecycle and bounded storage

Use a dedicated private directory for each process role. A filesystem lock prevents
concurrent managers from owning the same directory. No automatic collection occurs
on app restart. Sessions left active (or without a readable checkpoint) are recovered
as interrupted. The last checkpoint may omit work since its write; interrupted
sessions are always marked incomplete. A manager never resumes business uploads.

Defaults are 20 MiB per session, 100 MiB total per process directory, and 7 days.
Limits include reserved room for summary checkpoints. Old completed sessions are
removed before a new session reserves its maximum size. Age cleanup runs at manager
creation, start, or explicit cleanup; it is not an always-running background job.
After the detail cap, aggregates continue and omitted records are counted. The
writer queue is bounded to 1024 detail records. IO errors appear in status and do
not throw into SDK operations. No guarantees are made for sudden process death
before a checkpoint or filesystem power-loss durability.

`stop` disconnects the observer, drains only diagnostic work, and writes the final
summary. It never flushes, waits for, cancels or modifies SDK business uploads.
Open attempts remain `in_flight_uploads`; the summary is incomplete. Late completions
cannot enter a subsequent session. To include business drain time, flush/drain the
SDK externally first and then stop diagnostics. Start before SDK initialization to
observe its initial storage inventory. Keep the manager alive while collecting.

Management operations perform IO and should run off the UI thread. Export requires
a stopped session and a new destination outside diagnostic storage. Exported copies
are caller-owned and are not counted or removed by diagnostics retention. Detail
pagination uses a record offset and at most 1000 records per call. Historical files
are inspectable without enabling collection.

## Extension boundary

The core bridge is an internal contract with a default empty implementation. It
has no writer thread, local diagnostics storage or exporter while unregistered.
The optional component owns aggregation and local files. It has no network exporter,
does not reuse Log/RUM telemetry storage, and never logs its own failures through
the monitored SDK. A future uploader can consume completed exports independently.
