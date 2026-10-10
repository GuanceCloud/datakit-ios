#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
output="$(mktemp -d)"
trap 'rm -rf "$output"' EXIT
xcrun clang -fobjc-arc -fblocks -framework Foundation -Wall -Wextra \
  -I "$root/Sources/Diagnostics/include" -I "$root/Sources/Core/BaseUtils/include" \
  "$root/Sources/Core/BaseUtils/Base/FTDiagnosticsBridge.m" \
  "$root/Sources/Diagnostics/FTDiagnostics.m" "$root/Tests/Diagnostics/DiagnosticsTests.m" \
  -o "$output/diagnostics-tests"
"$output/diagnostics-tests"

xcrun clang -fobjc-arc -fblocks -framework Foundation \
  -I "$root/Sources/Diagnostics/include" \
  -I "$root/Sources/Core/BaseUtils/include" -I "$root/Sources/Core/DataManager/Upload" \
  "$root/Sources/Core/BaseUtils/Base/FTDiagnosticsBridge.m" \
  "$root/Sources/Diagnostics/FTDiagnostics.m" \
  "$root/Sources/Core/DataManager/Upload/FTHTTPClient.m" "$root/Tests/Diagnostics/HTTPDiagnosticsTests.m" \
  -o "$output/http-tests"
python3 "$root/tools/diagnostics/http_fixture.py" "$output/http-tests"
