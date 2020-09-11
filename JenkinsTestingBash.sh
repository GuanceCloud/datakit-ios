POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"

  case ${key} in
  -id)
    ACCESS_KEY_ID="$2"
    shift # past argumentandroid
    shift # past value
    ;;
  -sk)
    ACCESS_KEY_SECRET="$2"
    shift # past argumentandroid
    shift # past value
    ;;
  -url)
    ACCESS_SERVER_URL="$2"
    shift # past argument
    shift # past value
    ;;
  -tkn)
    ACCESS_DATAWAY_TOKEN="$2"
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

cd "SampleApp.xcodeproj/xcshareddata/xcschemes/"

sed -i -e 's/$ACCESS_KEY_ID/'"$ACCESS_KEY_ID"'/g' FTMobileSDKUnitTestsForCmd.xcscheme
sed -i -e 's/$ACCESS_KEY_SECRET/'"$ACCESS_KEY_SECRET"'/g' FTMobileSDKUnitTestsForCmd.xcscheme
sed -i -e 's~$ACCESS_SERVER_URL~'"$ACCESS_SERVER_URL"'~' FTMobileSDKUnitTestsForCmd.xcscheme
sed -i -e 's/$ACCESS_DATAWAY_TOKEN/'"$ACCESS_DATAWAY_TOKEN"'/g' FTMobileSDKUnitTestsForCmd.xcscheme

cd ../../..
pod install
xcodebuild test -workspace SampleApp.xcworkspace \
  -scheme FTMobileSDKUnitTestsForCmd \
  -destination "platform=iOS Simulator,name=iPhone SE (2nd generation),OS=13.7" \
  -only-testing FTMobileSDKUnitTests
