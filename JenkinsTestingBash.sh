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
set -o pipefail

if command -v xcbeautify > /dev/null 2>&1; then
    XCODEBUILD_FORMATTER="xcbeautify"
else
    XCODEBUILD_FORMATTER="cat"
    echo "Warning: xcbeautify not found. Falling back to raw xcodebuild output."
fi

cd "Examples/Examples.xcodeproj/xcshareddata/xcschemes/"

sed -i '' 's/$APP_ID/'"$APP_ID"'/g' FTMobileSDKUnitTestsForCmd.xcscheme
sed -i '' 's~$ACCESS_SERVER_URL~'"$ACCESS_SERVER_URL"'~' FTMobileSDKUnitTestsForCmd.xcscheme
sed -i '' 's/$TRACK_ID/'"$TRACK_ID"'/g' FTMobileSDKUnitTestsForCmd.xcscheme
sed -i '' 's~$TRACE_URL~'"$TRACE_URL"'~' FTMobileSDKUnitTestsForCmd.xcscheme

sed -i '' 's/$APP_ID/'"$APP_ID"'/g' FTMobileSDKUnitTestsTVOSForCmd.xcscheme
sed -i '' 's~$ACCESS_SERVER_URL~'"$ACCESS_SERVER_URL"'~' FTMobileSDKUnitTestsTVOSForCmd.xcscheme
sed -i '' 's/$TRACK_ID/'"$TRACK_ID"'/g' FTMobileSDKUnitTestsTVOSForCmd.xcscheme
sed -i '' 's~$TRACE_URL~'"$TRACE_URL"'~' FTMobileSDKUnitTestsTVOSForCmd.xcscheme

cd ../../../..
pod install

function findSimulator(){
    local TEST_SCHEME="$1"
    local TEST_SIMULATOR="$2"
    local DESTINATIONS
    local SIMULATOR_INFO
    local SIMULATOR_ID

    DESTINATIONS=$(xcodebuild -workspace FTMobileSDK.xcworkspace -scheme "${TEST_SCHEME}" -showdestinations)
    SIMULATOR_INFO=$(echo "$DESTINATIONS" | awk -v platform="${TEST_SIMULATOR}" '
      index($0, "{ platform:" platform) > 0 &&
      index($0, "id:") > 0 &&
      index($0, "OS:") > 0 &&
      index($0, "error:") == 0 {
        print
        exit
      }
    ')

    if [ -z "$SIMULATOR_INFO" ]; then
        echo "Error: No available ${TEST_SIMULATOR} found for scheme ${TEST_SCHEME}!"
        echo "$DESTINATIONS"
        exit 1
    fi

    SIMULATOR_ID=$(echo "$SIMULATOR_INFO" | sed -n 's/.*id:\([^,}]*\).*/\1/p' | sed 's/^ *//;s/ *$//')

    if [ -z "$SIMULATOR_ID" ]; then
        echo "Error: Failed to parse simulator id from destination:"
        echo "$SIMULATOR_INFO"
        exit 1
    fi

    echo "platform=${TEST_SIMULATOR},id=${SIMULATOR_ID}"
}

if [ -n "$DEVICE_DESTINATION" ]; then
    IOS_DESTINATION="$DEVICE_DESTINATION"
else
    IOS_DESTINATION=$(findSimulator "FTMobileSDKUnitTestsForCmd" "iOS Simulator")
fi

## Test iOS
xcodebuild test -workspace FTMobileSDK.xcworkspace \
-scheme FTMobileSDKUnitTestsForCmd \
-only-testing FTMobileSDKUnitTests \
-destination "$IOS_DESTINATION" | $XCODEBUILD_FORMATTER

TVOS_DESTINATION=$(findSimulator "FTMobileSDKUnitTestsTVOSForCmd" "tvOS Simulator")

## Test tvOS
xcodebuild test -workspace FTMobileSDK.xcworkspace \
-scheme FTMobileSDKUnitTestsTVOSForCmd \
-only-testing FTMobileSDKUnitTests-tvOS \
-destination "$TVOS_DESTINATION" | $XCODEBUILD_FORMATTER
