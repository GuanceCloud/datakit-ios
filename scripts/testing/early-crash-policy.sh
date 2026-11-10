#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
output="$(mktemp -d)"
trap 'rm -rf "$output"' EXIT
xcrun clang -std=c11 -Wall -Wextra -Werror \
  -I "$root/Sources/Core/BaseUtils/Base" \
  "$root/Sources/Core/BaseUtils/Base/FTEarlyCrash.c" \
  "$root/Tests/EarlyCrash/EarlyCrashPolicyTests.c" -o "$output/early-crash-policy"
"$output/early-crash-policy"

xcrun clang -std=c11 -Wall -Wextra -Werror -Dpwrite=ft_earlyCrashTestWrite \
  -I "$root/Sources/Core/BaseUtils/Base" \
  -c "$root/Sources/Core/BaseUtils/Base/FTEarlyCrash.c" -o "$output/early-crash-policy.o"
xcrun clang -std=c11 -Wall -Wextra -Werror \
  -I "$root/Sources/Core/BaseUtils/Base" \
  "$root/Tests/EarlyCrash/EarlyCrashReentryTests.c" "$output/early-crash-policy.o" \
  -o "$output/early-crash-reentry"
"$output/early-crash-reentry"
