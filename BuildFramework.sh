# 示例：sh BuildFramework.sh FTMobileSDK
# 注意：无 dynamic 后缀都为静态库
# 主项目需要的SDK ：FTMobileSDK 、 FTMobileSDK-dynamic
# 小组件 Widget Extension 中需要的 SDK ：FTMobileExtension
# 打包好的 SDK 存放在当前文件夹下的 build 文件夹内


buildFrameWorkWithName(){
SCHEME_NAME="$1"
WORK_DIR="./build/${SCHEME_NAME}"
FRAMEWORK_NAME=${SCHEME_NAME%%-*}
rm -r ${WORK_DIR}

#framework的输出目录
OUTPUT_DIR=FRAMEWORK/${FRAMEWORK_NAME}'.framework'

##xcodebuild打包
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
