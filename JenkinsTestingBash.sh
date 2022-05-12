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

cd "App.xcodeproj/xcshareddata/xcschemes/"

sed -i '' 's/$APP_ID/'"$APP_ID"'/g' FTMobileSDKUnitTestsForCmd.xcscheme
sed -i '' 's~$ACCESS_SERVER_URL~'"$ACCESS_SERVER_URL"'~' FTMobileSDKUnitTestsForCmd.xcscheme
sed -i '' 's/$TRACK_ID/'"$TRACK_ID"'/g' FTMobileSDKUnitTestsForCmd.xcscheme

cd ../../..
pod install

xcodebuild test -workspace App.xcworkspace \
  -scheme FTMobileSDKUnitTestsForCmd \
  -only-testing FTMobileSDKUnitTests \
  -destination "$DEVICE_DESTINATION"
