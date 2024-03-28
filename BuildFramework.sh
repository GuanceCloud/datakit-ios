# 示例：sh BuildFramework.sh FTMobileSDK
# 主项目需要的SDK ：FTMobileSDK
# 小组件 Widget Extension 中需要的 SDK ：FTMobileExtension
# 打包好的 SDK 存放在当前文件夹下的 FRAMEWORK 文件夹内

# 可以按需求修改下面的配置
# 真机 arch 架构
IPHONEOS_ARCH="arm64"
# 模拟器 arch 架构
IPHONESIMULATOR_ARCH="x86_64"


buildFrameWorkWithName(){

FRAMEWORK_NAME="$1"
WORK_DIR='build'
#release环境下，generic ios device编译出的framework。这个framework只能供真机运行。
DEVICE_DIR=${WORK_DIR}/'Release-iphoneos'/${FRAMEWORK_NAME}'.framework'
#release环境下，simulator编译出的framework。这个framework只能供模拟器运行。
SIMULATOR_DIR=${WORK_DIR}/'Release-iphonesimulator'/${FRAMEWORK_NAME}'.framework'
#framework的输出目录
OUTPUT_DIR=FRAMEWORK/${FRAMEWORK_NAME}'.framework'

##xcodebuild打包
xcodebuild -target ${FRAMEWORK_NAME} -arch ${IPHONEOS_ARCH}  ONLY_ACTIVE_ARCH=NO -configuration 'Relase'   -sdk iphoneos

xcodebuild -target ${FRAMEWORK_NAME} -arch ${IPHONESIMULATOR_ARCH} ONLY_ACTIVE_ARCH=NO -configuration 'Relase' -sdk iphonesimulator

#如果输出目录存在，即移除该目录，再创建该目录。目的是为了清空输出目录。
if [ -d ${OUTPUT_DIR} ]; then
rm -rf ${OUTPUT_DIR}
fi
mkdir -p ${OUTPUT_DIR}

echo "FRAMEWORK_OUTPUT_DIR: ${OUTPUT_DIR}"

#复制release-simulator下的framework到输出目录
cp -r ${DEVICE_DIR}/ ${OUTPUT_DIR}/


#lipo命令合并两种framework，将SVProgressHUD.framework/SVProgressHUD，覆盖输出到输出目录。
lipo -create ${DEVICE_DIR}/${FRAMEWORK_NAME} ${SIMULATOR_DIR}/${FRAMEWORK_NAME} -output ${OUTPUT_DIR}/${FRAMEWORK_NAME}

rm -r ${WORK_DIR}
echo "--------------END--------------"
}
echo "--------------START--------------"
echo "IPHONEOS_ARCH: ${IPHONEOS_ARCH}"
echo "IPHONESIMULATOR_ARCH: ${IPHONESIMULATOR_ARCH}"
echo "FRAMEWORK_NAME: $1"

buildFrameWorkWithName $1

