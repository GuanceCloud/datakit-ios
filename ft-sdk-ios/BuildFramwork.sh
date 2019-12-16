
 #xcodebuild  -workspace App.xcworkspace -sdk iphoneos -scheme "${APP_NAME}" -configuration "Release" clean archive -archivePath "./build/${APP_NAME}.xcarchive"

buildFrameWorkWithName(){

FRAMEWORK_NAME="$1"
WORK_DIR='build'
#release环境下，generic ios device编译出的framework。这个framework只能供真机运行。
DEVICE_DIR=${WORK_DIR}/'Release-iphoneos'/${FRAMEWORK_NAME}'.framework'
#release环境下，simulator编译出的framework。这个framework只能供模拟器运行。
SIMULATOR_DIR=${WORK_DIR}/'Release-iphonesimulator'/${FRAMEWORK_NAME}'.framework'
#framework的输出目录
OUTPUT_DIR=${SRCROOT}/'Pod_Products'/${FRAMEWORK_NAME}'.framework'

##xcodebuild打包
xcodebuild -target ${FRAMEWORK_NAME} -arch arm64 -arch armv7 -arch armv7s -arch arm64e ONLY_ACTIVE_ARCH=NO -configuration 'Relase'   -sdk iphoneos  

xcodebuild -target ${FRAMEWORK_NAME} -arch x86_64 -arch i386 ONLY_ACTIVE_ARCH=NO -configuration 'Relase' -sdk iphonesimulator  

#如果输出目录存在，即移除该目录，再创建该目录。目的是为了清空输出目录。
if [ -d ${OUTPUT_DIR} ]; then
rm -rf ${OUTPUT_DIR}
fi
mkdir -p ${OUTPUT_DIR}

#复制release-simulator下的framework到输出目录
cp -r ${DEVICE_DIR}/ ${OUTPUT_DIR}/


#lipo命令合并两种framework，将SVProgressHUD.framework/SVProgressHUD，覆盖输出到输出目录。
lipo -create ${DEVICE_DIR}/${FRAMEWORK_NAME} ${SIMULATOR_DIR}/${FRAMEWORK_NAME} -output ${OUTPUT_DIR}/${FRAMEWORK_NAME}

rm -r ${WORK_DIR}

# open ${OUTPUT_DIR}

}

buildFrameWorkWithName 'FTMobileAgent'
buildFrameWorkWithName 'FTAutoTrack'



#打开输出目录
