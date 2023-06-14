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

cd "Examples/Examples.xcodeproj/xcshareddata/xcschemes/"

echo $TRACE_URL

sed -i '' 's/$APP_ID/'"$APP_ID"'/g' FTMobileSDKUITestsForCmd.xcscheme
sed -i '' 's~$ACCESS_SERVER_URL~'"$ACCESS_SERVER_URL"'~' FTMobileSDKUITestsForCmd.xcscheme
sed -i '' 's/$TRACK_ID/'"$TRACK_ID"'/g' FTMobileSDKUITestsForCmd.xcscheme
sed -i '' 's~$TRACE_URL~'"$TRACE_URL"'~' FTMobileSDKUITestsForCmd.xcscheme

cd ../../..
pod install

xcodebuild test -workspace Examples.xcworkspace \
   -scheme FTMobileSDKUITestsForCmd \
   -only-testing FTMobileSDKUITests \
   -destination "$DEVICE_DESTINATION"

