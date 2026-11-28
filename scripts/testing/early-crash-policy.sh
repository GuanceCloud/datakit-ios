#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
output="$(mktemp -d)"
trap 'rm -rf "$output"' EXIT
crash="$root/Sources/Core/FTRUM/FTCrash"
base="$root/Sources/Core/BaseUtils"
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
  "$base/Base/FTCrashLogger.c" \
  "$crash/RecordingCore/FTCrashMonitorAPI.c" \
  "$root/Tests/EarlyCrash/EarlyCrashPolicyTests.c" "$output/crash-entry.o" -o "$output/early-crash-policy"
"$output/early-crash-policy"

# The only injected seam is the existing POSIX write primitive.
xcrun clang -std=gnu11 -Wall -Wextra -Werror -Dwrite=ft_earlyCrashTestWrite \
  -I "$root/Sources/Core/BaseUtils/Base" -I "$root/Sources/Core/BaseUtils/Thread/include" \
  -I "$crash/RecordingCore" \
  -c "$crash/RecordingCore/FTCrashFileUtils.c" -o "$output/file-utils.o"
xcrun clang -std=gnu11 -Wall -Wextra -Werror \
  -I "$root/Sources/Core/BaseUtils/Base" -I "$root/Sources/Core/BaseUtils/Thread/include" \
  -I "$crash/Recording/Monitors" -I "$crash/RecordingCore" \
  "$root/Sources/Core/BaseUtils/Base/FTEarlyCrash.c" \
  "$crash/Recording/Monitors/FTCrashMonitor_AppState.c" \
  "$crash/RecordingCore/FTCrashJSONCodec.c" "$base/Base/FTCrashLogger.c" \
  "$crash/RecordingCore/FTCrashMonitorAPI.c" "$output/file-utils.o" \
  "$root/Tests/EarlyCrash/EarlyCrashReentryTests.c" -o "$output/early-crash-reentry"
"$output/early-crash-reentry"

# Capture the C logger's OSLog calls without relying on system log settings.
xcrun clang -std=gnu11 -Wall -Wextra -Werror -mmacosx-version-min=12.0 \
  -Dos_log_create=ft_testCreateCrashLog -Dos_log_type_enabled=ft_testCrashLogTypeEnabled \
  -D_os_log_error_impl=ft_testWriteCrashLog \
  -c "$base/Base/FTCrashLogger.c" -o "$output/crash-logger.o"
xcrun clang -fobjc-arc -Wno-nullability-completeness -framework Foundation \
  -I "$base/Base" -I "$base/include" -I "$base/Thread/include" \
  "$base/Base/FTLog.m" "$base/Base/FTLogMessage.m" "$base/Base/FTFileLogger.m" \
  "$base/Base/FTOSLogger.m" "$base/Base/FTInternalConstants.m" "$base/Base/NSDate+FTUtil.m" \
  "$output/crash-logger.o" \
  "$root/Tests/EarlyCrash/CrashMonitorLoggingTests.m" -o "$output/crash-monitor-logging"
"$output/crash-monitor-logging"

# 用真实的 NSException / Signal monitor 对接其他崩溃 SDK；采集相关的辅助函数在测试里做了桩。
crash_inc=(-I "$base/Base" -I "$base/include" -I "$base/Thread/include" -I "$root/Sources/Core/FTRUM/include"
  -I "$crash/Recording" -I "$crash/Recording/Monitors" -I "$crash/RecordingCore")
xcrun clang -std=gnu11 -Wall -Wextra -Werror -Wno-missing-field-initializers -mmacosx-version-min=12.0 "${crash_inc[@]}" \
  -c "$crash/Recording/Monitors/FTCrashMonitor_Signal.c" -o "$output/monitor-signal.o"
xcrun clang -fobjc-arc -Wall -Wextra -Werror -Wno-missing-field-initializers -Wno-nullability-completeness -mmacosx-version-min=12.0 \
  "${crash_inc[@]}" -framework Foundation \
  "$crash/Recording/Monitors/FTCrashMonitor_NSException.m" "$output/monitor-signal.o" \
  "$crash/RecordingCore/FTCrashSignalInfo.c" "$crash/RecordingCore/FTCrashMonitorAPI.c" \
  "$root/Tests/EarlyCrash/CrashHandlerReinstallTests.m" -o "$output/crash-handler-reinstall"
"$output/crash-handler-reinstall"
