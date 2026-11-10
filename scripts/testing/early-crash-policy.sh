#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
output="$(mktemp -d)"
trap 'rm -rf "$output"' EXIT
crash="$root/Sources/Core/FTRUM/FTCrash"
# Only the SDK-origin getter is controlled. Fatal/manual/report filtering and
# callback ordering execute the real production FTCrashC.c entry point.
xcrun clang -std=gnu11 -Wall -Wextra -Werror -ffunction-sections -fdata-sections \
  -Dft_earlyCrashStartTime=ft_earlyCrashTestSDKStart \
  -I "$root/Sources/Core/BaseUtils/Base" -I "$root/Sources/Core/BaseUtils/Thread/include" \
  -I "$root/Sources/Core/FTRUM/include" -I "$crash/Recording" \
  -I "$crash/Recording/Monitors" -I "$crash/RecordingCore" \
  -c "$crash/Recording/FTCrashC.c" -o "$output/crash-entry.o"
xcrun clang -std=gnu11 -Wall -Wextra -Werror -Wl,-dead_strip \
  -I "$root/Sources/Core/FTRUM/include" -I "$crash/Recording" \
  -I "$root/Sources/Core/BaseUtils/Base" \
  -I "$root/Sources/Core/BaseUtils/Thread/include" \
  -I "$crash/Recording/Monitors" -I "$crash/RecordingCore" \
  "$root/Sources/Core/BaseUtils/Base/FTEarlyCrash.c" \
  "$crash/Recording/Monitors/FTCrashMonitor_AppState.c" \
  "$crash/RecordingCore/FTCrashJSONCodec.c" \
  "$crash/RecordingCore/FTCrashFileUtils.c" \
  "$crash/RecordingCore/FTCrashLogger.c" \
  "$crash/RecordingCore/FTCrashMonitorAPI.c" \
  "$root/Tests/EarlyCrash/EarlyCrashPolicyTests.c" "$output/crash-entry.o" -o "$output/early-crash-policy"
"$output/early-crash-policy"

# The only injected seam is the existing POSIX write primitive.
xcrun clang -std=gnu11 -Wall -Wextra -Werror -Dwrite=ft_earlyCrashTestWrite \
  -I "$root/Sources/Core/BaseUtils/Thread/include" -I "$crash/RecordingCore" \
  -c "$crash/RecordingCore/FTCrashFileUtils.c" -o "$output/file-utils.o"
xcrun clang -std=gnu11 -Wall -Wextra -Werror \
  -I "$root/Sources/Core/BaseUtils/Base" -I "$root/Sources/Core/BaseUtils/Thread/include" \
  -I "$crash/Recording/Monitors" -I "$crash/RecordingCore" \
  "$root/Sources/Core/BaseUtils/Base/FTEarlyCrash.c" \
  "$crash/Recording/Monitors/FTCrashMonitor_AppState.c" \
  "$crash/RecordingCore/FTCrashJSONCodec.c" "$crash/RecordingCore/FTCrashLogger.c" \
  "$crash/RecordingCore/FTCrashMonitorAPI.c" "$output/file-utils.o" \
  "$root/Tests/EarlyCrash/EarlyCrashReentryTests.c" -o "$output/early-crash-reentry"
"$output/early-crash-reentry"
