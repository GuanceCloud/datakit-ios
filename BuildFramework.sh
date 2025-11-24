# Example: sh BuildFramework.sh FTMobileSDK
# Note: All without dynamic suffix are static libraries
# SDK required by main project: FTMobileSDK, FTMobileSDK-dynamic
# SDK required by Widget Extension: FTMobileExtension
# The packaged SDK is stored in the build folder under the current directory


buildFrameWorkWithName(){
SCHEME_NAME="$1"
WORK_DIR="./build/${SCHEME_NAME}"
FRAMEWORK_NAME=${SCHEME_NAME%%-*}
rm -r ${WORK_DIR}

# Framework output directory
OUTPUT_DIR=FRAMEWORK/${FRAMEWORK_NAME}'.framework'

## xcodebuild packaging
xcodebuild archive \
  -scheme ${SCHEME_NAME} \
  -archivePath "${WORK_DIR}/ios.xcarchive" \
  -sdk iphoneos \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

xcodebuild archive \
  -scheme ${SCHEME_NAME} \
  -archivePath "${WORK_DIR}/ios-sim.xcarchive" \
  -sdk iphonesimulator \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES


xcodebuild -create-xcframework \
  -framework "${WORK_DIR}/ios.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework" \
  -framework "${WORK_DIR}/ios-sim.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework" \
  -output "${WORK_DIR}/${FRAMEWORK_NAME}.xcframework"



#rm -r ${WORK_DIR}
echo "--------------END--------------"
}
echo "--------------START--------------"
echo "SCHEME_NAME: $1"

buildFrameWorkWithName $1
