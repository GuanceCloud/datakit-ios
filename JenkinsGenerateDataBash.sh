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
    shift # past argumentandroid
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

cd "$SCHEME_DIR"

echo $TRACE_URL

sed -i '' 's/$APP_ID/'"$APP_ID"'/g' FTMobileSDKUITestsForCmd.xcscheme
sed -i '' 's~$ACCESS_SERVER_URL~'"$ACCESS_SERVER_URL"'~' FTMobileSDKUITestsForCmd.xcscheme
sed -i '' 's/$TRACK_ID/'"$TRACK_ID"'/g' FTMobileSDKUITestsForCmd.xcscheme
sed -i '' 's~$TRACE_URL~'"$TRACE_URL"'~' FTMobileSDKUITestsForCmd.xcscheme

cd "$SCRIPT_DIR"
pod install

if [ -z "$DEVICE_DESTINATION" ]; then
  echo "Error: -devicedestination is required"
  exit 1
fi

xcodebuild test -workspace FTSDK.xcworkspace \
   -scheme FTMobileSDKUITestsForCmd \
   -only-testing FTMobileSDKUITests \
   -destination "$DEVICE_DESTINATION"
