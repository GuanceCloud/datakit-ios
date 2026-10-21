#!/bin/sh
if [ -z "${BASH_VERSION:-}" ]; then
exec /bin/bash "$0" "$@"
fi

case ":${SHELLOPTS:-}:" in
*:posix:*)
exec /bin/bash "$0" "$@"
;;
esac

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
bash "${SCRIPT_DIR}/tools/diagnostics/test.sh"
SCHEME_DIR="${SCRIPT_DIR}/Examples/Examples.xcodeproj/xcshareddata/xcschemes"
APP_ID="${APP_ID:-}"
ACCESS_SERVER_URL="${ACCESS_SERVER_URL:-}"
TRACK_ID="${TRACK_ID:-}"
TRACE_URL="${TRACE_URL:-}"
DEVICE_DESTINATION="${DEVICE_DESTINATION:-}"

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"

  case ${key} in
  -rumid)
    APP_ID="$2"
    shift # past argument
    shift # past value
    ;;
  -url)
    ACCESS_SERVER_URL="$2"
    shift # past argument
    shift # past value
    ;;
  -trackid)
    TRACK_ID="$2"
    shift # past argument
    shift # past value
    ;;
  -traceurl)
    TRACE_URL="$2"
    shift # past argument
    shift # past value
    ;;
  -devicedestination)
    DEVICE_DESTINATION="$2"
    shift # past argument
    shift # past value
    ;;
  --default)
    DEFAULT=YES
    shift # past argument
    ;;
  *) # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift              # past argument
    ;;
  esac
done
set -- "${POSITIONAL[@]}" # restore positional parametersCERT_FILE

if command -v xcbeautify > /dev/null 2>&1; then
    XCODEBUILD_FORMATTER="xcbeautify"
else
    XCODEBUILD_FORMATTER="cat"
    echo "Warning: xcbeautify not found. Falling back to raw xcodebuild output."
fi

cd "$SCHEME_DIR"

sed -i '' 's/$APP_ID/'"$APP_ID"'/g' FTMobileSDKUnitTestsForCmd.xcscheme
sed -i '' 's~$ACCESS_SERVER_URL~'"$ACCESS_SERVER_URL"'~' FTMobileSDKUnitTestsForCmd.xcscheme
sed -i '' 's/$TRACK_ID/'"$TRACK_ID"'/g' FTMobileSDKUnitTestsForCmd.xcscheme
sed -i '' 's~$TRACE_URL~'"$TRACE_URL"'~' FTMobileSDKUnitTestsForCmd.xcscheme

sed -i '' 's/$APP_ID/'"$APP_ID"'/g' FTMobileSDKUnitTestsTVOSForCmd.xcscheme
sed -i '' 's~$ACCESS_SERVER_URL~'"$ACCESS_SERVER_URL"'~' FTMobileSDKUnitTestsTVOSForCmd.xcscheme
sed -i '' 's/$TRACK_ID/'"$TRACK_ID"'/g' FTMobileSDKUnitTestsTVOSForCmd.xcscheme
sed -i '' 's~$TRACE_URL~'"$TRACE_URL"'~' FTMobileSDKUnitTestsTVOSForCmd.xcscheme

cd "$SCRIPT_DIR"
pod install

function findSimulator(){
    local TEST_SCHEME="$1"
    local TEST_SIMULATOR="$2"
    local REQUESTED_DESTINATION="${3:-}"
    local DESTINATIONS
    local SELECTED_DESTINATION

    if ! DESTINATIONS=$(xcodebuild -workspace FTSDK.xcworkspace -scheme "${TEST_SCHEME}" -showdestinations); then
        echo "Error: Failed to query destinations for scheme ${TEST_SCHEME}!" >&2
        return 1
    fi

    SELECTED_DESTINATION=$(printf '%s\n' "$DESTINATIONS" | awk \
      -v platform="${TEST_SIMULATOR}" -v requested="${REQUESTED_DESTINATION}" '
      function trim(value) {
        sub(/^[[:space:]]+/, "", value)
        sub(/[[:space:]]+$/, "", value)
        return value
      }
      BEGIN {
        count = split(requested, parts, ",")
        for (i = 1; i <= count; i++) {
          separator = index(parts[i], "=")
          if (!separator) { invalid = 1; continue }
          key = trim(substr(parts[i], 1, separator - 1))
          wanted[key] = trim(substr(parts[i], separator + 1))
        }
      }
      /Destinations incompatible|Ineligible destinations/ { ineligible = 1 }
      /^[[:space:]]*\{[[:space:]]*platform:/ && !ineligible {
        for (key in fields) delete fields[key]
        line = $0
        sub(/^[[:space:]]*\{[[:space:]]*/, "", line)
        sub(/[[:space:]]*\}[[:space:]]*$/, "", line)
        count = split(line, parts, ",")
        for (i = 1; i <= count; i++) {
          separator = index(parts[i], ":")
          if (!separator) continue
          key = trim(substr(parts[i], 1, separator - 1))
          fields[key] = trim(substr(parts[i], separator + 1))
        }
        if (!fields["id"] || fields["id"] ~ /placeholder/ || "error" in fields) next
        if (!fallback && fields["platform"] == platform && fields["OS"]) {
          fallback = "platform=" platform ",id=" fields["id"]
        }
        if (!requested || invalid) next
        matches = 1
        for (key in wanted) {
          if (key == "OS" && wanted[key] == "latest" && fields["OS"]) continue
          if (!(key in fields) || fields[key] != wanted[key]) matches = 0
        }
        if (matches) matched = 1
      }
      END {
        if (matched) print requested
        else if (fallback) print fallback
      }
    ')

    if [ -z "$SELECTED_DESTINATION" ]; then
        echo "Error: No available ${TEST_SIMULATOR} found for scheme ${TEST_SCHEME}!" >&2
        printf '%s\n' "$DESTINATIONS" >&2
        return 1
    fi

    if [ -n "$REQUESTED_DESTINATION" ] && [ "$SELECTED_DESTINATION" != "$REQUESTED_DESTINATION" ]; then
        echo "Warning: Destination '${REQUESTED_DESTINATION}' is unavailable for ${TEST_SCHEME}; using '${SELECTED_DESTINATION}'." >&2
    fi
    printf '%s\n' "$SELECTED_DESTINATION"
}

IOS_DESTINATION=$(findSimulator "FTMobileSDKUnitTestsForCmd" "iOS Simulator" "$DEVICE_DESTINATION")

## Test iOS
xcodebuild test -workspace FTSDK.xcworkspace \
-scheme FTMobileSDKUnitTestsForCmd \
-only-testing FTMobileSDKUnitTests \
-destination "$IOS_DESTINATION" | $XCODEBUILD_FORMATTER

TVOS_DESTINATION=$(findSimulator "FTMobileSDKUnitTestsTVOSForCmd" "tvOS Simulator")

## Test tvOS
xcodebuild test -workspace FTSDK.xcworkspace \
-scheme FTMobileSDKUnitTestsTVOSForCmd \
-only-testing FTMobileSDKUnitTests-tvOS \
-destination "$TVOS_DESTINATION" | $XCODEBUILD_FORMATTER
