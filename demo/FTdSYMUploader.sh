#!/bin/bash
#
# This is the upload dSYM script
#
######################################################
# 1. 脚本集成到 Xcode工 程的 Target
######################################################
#
# --- Copy the SCRIPT to the Run Script of Build Phases in the Xcode project ---
#
# #
FT_APP_ID="YOUR_APP_ID"
#dea_address
FT_DEA_ADDRESS="YOUR_DEA_ADDRESS"
# 环境字段。属性值：prod/gray/pre/common/local。需要与 SDK 设置一致
FT_ENV="common"
#
# 脚本默认配置的版本格式为CFBundleShortVersionString,如果你修改默认的版本格式, 请设置此变量。注意：需要确保在此填写的与SDK设置的一致。
# FT_VERSION=""
#
# Debug模式编译是否上传，1＝上传 0＝不上传，默认不上传
# UPLOAD_DEBUG_SYMBOLS=0
#
# # 模拟器编译是否上传，1=上传 0=不上传，默认不上传
# UPLOAD_SIMULATOR_SYMBOLS=0
#
# #只有Archive操作时上传, 1=支持Archive上传 0=所有Release模式编译都上传
UPLOAD_ARCHIVE_ONLY=1
# #
# source FTdSYMUpload.sh
#
# --- END OF SCRIPT ---
#
#
#######################################################
# 2. 脚本根据输入参数处理
#######################################################
#
# #命令行下输入应用基本信息, .dSYM文件的父目录路径, 输出文件目录即可
#
# sh dSYMUpload.sh <sdk_url> <rum_app_id> <app_version> <app_env> <bSYMBOL_src_dir> <bSYMBOL_dest_dir>
#
#

#
# --- CONTENT OF SCRIPT ---
#

# 打印错误信息
function exitWithMessage(){
    echo "--------------------------------"
    echo "${1}"
    echo "--------------------------------"
    exit ${2}
}

# 上传bSYMBOL文件
function dSYMUpload(){
    P_SDK_URL="$1"
    P_RUM_APP_ID="$2"
    P_APP_VERSION="$3"
    P_APP_ENV="$4"
    P_BSYMBOL_ZIP_FILE="$5"
    
    #
    P_BSYMBOL_ZIP_FILE_NAME=${P_BSYMBOL_ZIP_FILE##*/}
    P_BSYMBOL_ZIP_FILE_NAME=${P_BSYMBOL_ZIP_FILE_NAME//&/_}
    P_BSYMBOL_ZIP_FILE_NAME="${P_BSYMBOL_ZIP_FILE_NAME// /_}"
    echo "P_BSYMBOL_ZIP_FILE_NAME: ${P_BSYMBOL_ZIP_FILE_NAME}"
    DSYM_UPLOAD_URL="${FT_DEA_ADDRESS}/v1/rum/sourcemap?app_id=${P_RUM_APP_ID}&env=${P_APP_ENV}&version=${P_APP_VERSION}&platform=ios"
    echo "dSYM upload url: ${DSYM_UPLOAD_URL}"
    
    echo "-----------------------------"
    STATUS=$(curl -X POST "${DSYM_UPLOAD_URL}"  -F "file=@${P_BSYMBOL_ZIP_FILE}" -H "Content-Type: multipart/form-data")
    echo "-----------------------------"
    
    UPLOAD_RESULT="FAILTURE"
    echo "Upload server response: ${STATUS}"
    
    if [ ! "${STATUS}" ]; then
    echo "Error: Failed to upload the zip archive file."
    elif [[ "${STATUS}" == *"{\"code\":200"* ]]; then
    echo "Success to upload the dSYM for the app [${P_APP_ENV} ${P_APP_VERSION}]"
    UPLOAD_RESULT="SUCCESS"
    else
    echo "Error: Failed to upload the zip archive file to DataKit."
    fi
    #Remove temp dSYM archive
    echo "Remove temporary zip archive: ${DSYM_ZIP_FPATH}"
    #    rm -f "${P_BSYMBOL_ZIP_FILE}"
    
    if [ "$?" -ne 0 ]; then
    exitWithMessage "Error: Failed to remove temporary zip archive." 0
    fi
    
    echo "--------------------------------"
    echo "${UPLOAD_RESULT} - dSYM upload complete."
    
    if [[ "${UPLOAD_RESULT}" == "FAILTURE" ]]; then
    echo "--------------------------------"
    echo "Failed to upload the dSYM"
    echo "Please check the script and try it again."
    fi
}

#执行
function run() {
    CONFIG_SDK_URL="$1"
    CONFIG_APP_ID="$2"
    
    CONFIG_APP_VERSION="$3"
    CONFIG_APP_ENV="$4"
    CONFIG_DSYM_SOURCE_DIR="$5"
    CONFIG_DSYM_DEST_DIR="$6"

    # 检查必须参数是否设置
    if [ ! "${CONFIG_APP_ID}" ]; then
    exitWithMessage "Error: RUM App ID not defined. Please set 'FT_RUM_APP_ID' " 0
    fi
    
    if [[ "${CONFIG_APP_ID}" == *"App ID"* ]]; then
    exitWithMessage "Error: RUM App ID not defined." 0
    fi
    
    if [ ! "${CONFIG_APP_VERSION}" ]; then
    exitWithMessage "Error: App Version not defined." 0
    fi
    
    if [ ! "${CONFIG_APP_ENV}" ]; then
    exitWithMessage "Error: SDK Env not defined." 0
    fi
    
    if [ ! -e "${CONFIG_DSYM_SOURCE_DIR}" ]; then
    exitWithMessage "Error: Invalid Source dir ${CONFIG_DSYM_SOURCE_DIR}" 0
    fi
    
    if [ ! "${CONFIG_DSYM_DEST_DIR}" ]; then
    exitWithMessage "Error: Invalid Dest dir ${CONFIG_DSYM_DEST_DIR}" 0
    fi
    
    if [ ! -e "${CONFIG_DSYM_DEST_DIR}" ]; then
    mkdir ${CONFIG_DSYM_DEST_DIR}
    fi
    
    DSYM_FOLDER="${CONFIG_DSYM_SOURCE_DIR}"
    IFS=$'\n'
    
    echo "Scaning dSYM FOLDER: ${DSYM_FOLDER} ..."
    RET="F"
    
    #
    for dsymFile in $(find "$DSYM_FOLDER" -name '*.dSYM'); do
    RET="T"
    echo "Found dSYM file: $dsymFile"
    cp -rf $dsymFile $CONFIG_DSYM_DEST_DIR
    done
    if [ $RET = "T" ]; then
    DSYM_SYMBOL_ZIP_FILE_NAME="DSYM_SYMBOL.zip"
    DSYM_SYMBOL_ZIP_FILE_NAME="${DSYM_SYMBOL_ZIP_FILE_NAME// /_}"
    DSYM_SYMBOL_ZIP_FILE=${CONFIG_DSYM_DEST_DIR}/${DSYM_SYMBOL_ZIP_FILE_NAME}
    
    if [ -e $DSYM_SYMBOL_ZIP_FILE ]; then
    rm -f $DSYM_SYMBOL_ZIP_FILE
    fi
    # 压缩dSYM目录
    pushd $CONFIG_DSYM_DEST_DIR
    zip -r -q $DSYM_SYMBOL_ZIP_FILE *
    popd
    # 上传
    dSYMUpload $CONFIG_SDK_URL $CONFIG_APP_ID $CONFIG_APP_VERSION $CONFIG_APP_ENV $DSYM_SYMBOL_ZIP_FILE
    fi
    
    if [ $RET = "F" ]; then
    exitWithMessage "No .dSYM found in ${DSYM_FOLDER}" 0
    fi
}
# 检查App的dSYM文件是否为空，若为空，循环等待10s后还为空则退出
function checkAppSourceFile(){
    dsymFile="$1"
    DSYM_APP_FILE_IS_EXIST=1
    for i in {1..10}; do
    sleep 1
    for dsymSingleFile in $(find "${dsymFile}" -name ${PRODUCT_NAME}); do
    if [ -s "${dsymSingleFile}" ]; then
    DSYM_APP_FILE_IS_EXIST=0
    return $DSYM_APP_FILE_IS_EXIST
    fi
    done
    done
    return $DSYM_APP_FILE_IS_EXIST
}

# 在Xcode工程中执行
function runInXcode(){
    echo "Uploading dSYM in Xcode ..."
    
    echo "Info.Plist : ${INFOPLIST_FILE}"

    BUNDLE_SHORT_VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "${INFOPLIST_FILE}")
    if [[ "${BUNDLE_SHORT_VERSION}" == *"MARKETING_VERSION"* ]]; then
    BUNDLE_SHORT_VERSION=${MARKETING_VERSION}
    fi
    echo "BUNDLE_SHORT_VERSION: $BUNDLE_SHORT_VERSION"
    
    # 组装默认识别的版本信息(格式为CFBundleShortVersionString, 例如: 1.0)
    if [ ! "${FT_VERSION}" ]; then
    FT_APP_VERSION="${BUNDLE_SHORT_VERSION}"
    else
    FT_APP_VERSION="${FT_VERSION}"
    fi
    
    echo "--------------------------------"
    echo "Prepare application information."
    echo "--------------------------------"
    
    echo "Product Name: ${PRODUCT_NAME}"
    echo "Version: ${FT_APP_VERSION}"
    
    echo "RUM App ID: ${FT_APP_ID}"
    
    echo "--------------------------------"
    echo "Check the arguments ..."
    
    ##检查模拟器编译是否允许上传符号
    if [ "$EFFECTIVE_PLATFORM_NAME" == "-iphonesimulator" ]; then
    if [ $UPLOAD_SIMULATOR_SYMBOLS -eq 0 ]; then
    exitWithMessage "Warning: Build for simulator and skipping to upload. \nYou can modify 'UPLOAD_SIMULATOR_SYMBOLS' to 1 in the script." 0
    fi
    fi
    
    ##检查是否是Release模式编译
    if [ "${CONFIGURATION=}" == "Debug" ]; then
    if [ $UPLOAD_DEBUG_SYMBOLS -eq 0 ]; then
    exitWithMessage "Warning: Build for debug mode and skipping to upload. \nYou can modify 'UPLOAD_DEBUG_SYMBOLS' to 1 in the script." 0
    fi
    fi
    
    ##检查是否Archive操作
    if [ $UPLOAD_ARCHIVE_ONLY -eq 1 ]; then
    if [[ "$TARGET_BUILD_DIR" == *"/Archive"* ]]; then
    echo "Archive the package"
    else
    exitWithMessage "Warning: Build for NOT Archive mode and skipping to upload. \nYou can modify 'UPLOAD_ARCHIVE_ONLY' to 0 in the script." 0
    fi
    fi
    
    ##检查dSYM文件是否完整
    for dsymFile in $(find "$DWARF_DSYM_FOLDER_PATH" -name '*.dSYM'); do
    FILE_NAME=${dsymFile##*/}
    FILE_NAME=${FILE_NAME//&/_}
    FILE_NAME="${FILE_NAME// /_}"
    if [[ "${FILE_NAME}" == "${PRODUCT_NAME}"* ]]; then
    SDYM_SINGLE_FILE_NAME="${dsymFile}/Contents/Resources/DWARF/${PRODUCT_NAME}"
    checkAppSourceFile $SDYM_SINGLE_FILE_NAME
    echo "checkAppSourceFile: $?"
    if [ $? == 1 ]; then
      exitWithMessage "Not Found File In ${SDYM_SINGLE_FILE_NAME}" 0
    fi
    fi
    done
    #
    run ${FT_DEA_ADDRESS} ${FT_APP_ID} ${FT_APP_VERSION} ${FT_ENV} ${DWARF_DSYM_FOLDER_PATH} ${BUILD_DIR}/SymbolTemp
}
# 根据Xcode的环境变量判断是否处于Xcode环境
INFO_PLIST_FILE="${INFOPLIST_FILE}"

BuildInXcode="F"
if [ -f "${INFO_PLIST_FILE}" ]; then
BuildInXcode="T"
fi

if [ $BuildInXcode = "T" ]; then
runInXcode
else
echo "\nUsage: dSYMUpload.sh <sdk_url> <rum_app_id> <app_version> <app_env> <dSYMBOL_src_dir> <dSYMBOL_dest_dir>\n"

# 你可以在此处直接设置 URL、APP_ID 和 APP_ENV排除不常变参数的输入
FT_SDK_URL="$1"
FT_RUM_APP_ID="$2"
FT_APP_VERSION="$3"
FT_APP_ENV="$4"
DWARF_DSYM_FOLDER_PATH="$5"
SYMBOL_OUTPUT_PATH="$6"

run ${FT_SDK_URL} ${FT_RUM_APP_ID} ${FT_APP_VERSION} ${FT_APP_ENV} ${DWARF_DSYM_FOLDER_PATH} ${SYMBOL_OUTPUT_PATH}
fi
