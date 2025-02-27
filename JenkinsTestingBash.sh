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
    TEST_SCHEME="$1"
    TEST_SIMULATOR="$2"
    
    # tvOS 测试用例
    SIMULATOR_INFO=$(xcodebuild -workspace FTMobileSDK.xcworkspace -scheme ${TEST_SCHEME}  -showdestinations | grep "${TEST_SIMULATOR}" | grep "OS:" | head -1)
        
    # 检查是否找到模拟器
    if [ -z "$SIMULATOR_INFO" ]; then
    echo "Error: No ${TEST_SIMULATOR} found!"
    exit 1
    fi
    
    # 提取模拟器的系统版本和 ID
    SIMULATOR_OS=$(echo "$SIMULATOR_INFO" | awk -F 'OS:' '{print $2}' | awk -F ',' '{print $1}')
    SIMULATOR_ID=$(echo "$SIMULATOR_INFO" | awk -F 'id:' '{print $2}' | awk -F ',' '{print $1}')
    
    # 构建 SIMULATOR_DESTINATION 字符串
    SIMULATOR_DESTINATION="platform=${TEST_SIMULATOR},OS=$SIMULATOR_OS,id=$SIMULATOR_ID"
    
    # 检查返回值是否为空
    if [ -z "$SIMULATOR_DESTINATION" ]; then
    echo "Error: Failed to get ${TEST_SIMULATOR} destination."
    exit 1
    fi
    
    echo "$SIMULATOR_DESTINATION"
}

IOS_DESTINATION=$(findSimulator "FTMobileSDKUnitTestsForCmd" "iOS Simulator")

## 测试 iOS
xcodebuild test -workspace FTMobileSDK.xcworkspace \
-scheme FTMobileSDKUnitTestsForCmd \
-only-testing FTMobileSDKUnitTests \
-destination "$IOS_DESTINATION"

TVOS_DESTINATION=$(findSimulator "FTMobileSDKUnitTestsTVOSForCmd" "tvOS Simulator")

## 测试 tvOS
xcodebuild test -workspace FTMobileSDK.xcworkspace \
-scheme FTMobileSDKUnitTestsTVOSForCmd \
-only-testing FTMobileSDKUnitTests-tvOS \
-destination "$TVOS_DESTINATION"

