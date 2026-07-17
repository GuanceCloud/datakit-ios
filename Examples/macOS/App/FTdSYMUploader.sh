#!/bin/bash
#
# This is the upload dSYM script
#
######################################################
# 1. Script integration into Xcode project Target
######################################################
#
# --- Copy the SCRIPT to the Run Script of Build Phases in the Xcode project ---
#
# #
FT_APP_ID="YOUR_APP_ID"
#dea_address
FT_DEA_ADDRESS="YOUR_DEA_ADDRESS"
# Environment field. Property value: prod/gray/pre/common/local. Must be consistent with SDK settings
FT_ENV="common"
#
# The script default configuration version format is CFBundleShortVersionString. If you modify the default version format, please set this variable. Note: Make sure what you fill in here is consistent with the SDK settings.
# FT_VERSION=""
#
# Whether to upload in Debug mode compilation, 1=upload 0=don't upload, default is don't upload
# UPLOAD_DEBUG_SYMBOLS=0
#
# # Whether to upload simulator compilation, 1=upload 0=don't upload, default is don't upload
# UPLOAD_SIMULATOR_SYMBOLS=0
#
# #Only upload during Archive operation, 1=support Archive upload 0=upload all Release mode compilations
UPLOAD_ARCHIVE_ONLY=1
# #
# source FTdSYMUpload.sh
#
# --- END OF SCRIPT ---
#
#
#######################################################
# 2. Script processing based on input parameters
#######################################################
#
# #Enter application basic information, .dSYM file parent directory path, output file directory on command line
#
# sh dSYMUpload.sh <sdk_url> <rum_app_id> <app_version> <app_env> <bSYMBOL_src_dir> <bSYMBOL_dest_dir>
#
#

#
# --- CONTENT OF SCRIPT ---
#

# Print error message
function exitWithMessage(){
    echo "--------------------------------"
    echo "${1}"
    echo "--------------------------------"
    exit ${2}
}

# Upload bSYMBOL file
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

#Execute
function run() {
    CONFIG_SDK_URL="$1"
    CONFIG_APP_ID="$2"
    
    CONFIG_APP_VERSION="$3"
    CONFIG_APP_ENV="$4"
    CONFIG_DSYM_SOURCE_DIR="$5"
    CONFIG_DSYM_DEST_DIR="$6"

    # Check if required parameters are set
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
    # Compress dSYM directory
    pushd $CONFIG_DSYM_DEST_DIR
    zip -r -q $DSYM_SYMBOL_ZIP_FILE *
    popd
    # Upload
    dSYMUpload $CONFIG_SDK_URL $CONFIG_APP_ID $CONFIG_APP_VERSION $CONFIG_APP_ENV $DSYM_SYMBOL_ZIP_FILE
    fi
    
    if [ $RET = "F" ]; then
    exitWithMessage "No .dSYM found in ${DSYM_FOLDER}" 0
    fi
}
# Check if the App's dSYM file is empty, if empty, wait 10s in a loop, if still empty then exit
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

# Execute in Xcode project
function runInXcode(){
    echo "Uploading dSYM in Xcode ..."
    
    echo "Info.Plist : ${INFOPLIST_FILE}"

    BUNDLE_SHORT_VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "${INFOPLIST_FILE}")
    if [[ "${BUNDLE_SHORT_VERSION}" == *"MARKETING_VERSION"* ]]; then
    BUNDLE_SHORT_VERSION=${MARKETING_VERSION}
    fi
    echo "BUNDLE_SHORT_VERSION: $BUNDLE_SHORT_VERSION"
    
    # Assemble default recognized version information (format is CFBundleShortVersionString, e.g.: 1.0)
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
    
    ##Check if simulator compilation allows symbol upload
    if [ "$EFFECTIVE_PLATFORM_NAME" == "-iphonesimulator" ]; then
    if [ $UPLOAD_SIMULATOR_SYMBOLS -eq 0 ]; then
    exitWithMessage "Warning: Build for simulator and skipping to upload. \nYou can modify 'UPLOAD_SIMULATOR_SYMBOLS' to 1 in the script." 0
    fi
    fi
    
    ##Check if it's Release mode compilation
    if [ "${CONFIGURATION=}" == "Debug" ]; then
    if [ $UPLOAD_DEBUG_SYMBOLS -eq 0 ]; then
    exitWithMessage "Warning: Build for debug mode and skipping to upload. \nYou can modify 'UPLOAD_DEBUG_SYMBOLS' to 1 in the script." 0
    fi
    fi
    
    ##Check if it's Archive operation
    if [ $UPLOAD_ARCHIVE_ONLY -eq 1 ]; then
    if [[ "$TARGET_BUILD_DIR" == *"/Archive"* ]]; then
    echo "Archive the package"
    else
    exitWithMessage "Warning: Build for NOT Archive mode and skipping to upload. \nYou can modify 'UPLOAD_ARCHIVE_ONLY' to 0 in the script." 0
    fi
    fi
    
    ##Check if dSYM file is complete
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
# Determine if in Xcode environment based on Xcode environment variables
INFO_PLIST_FILE="${INFOPLIST_FILE}"

BuildInXcode="F"
if [ -f "${INFO_PLIST_FILE}" ]; then
BuildInXcode="T"
fi

if [ $BuildInXcode = "T" ]; then
runInXcode
else
echo "\nUsage: dSYMUpload.sh <sdk_url> <rum_app_id> <app_version> <app_env> <dSYMBOL_src_dir> <dSYMBOL_dest_dir>\n"

# You can directly set URL, APP_ID and APP_ENV here to exclude input of parameters that don't change often
FT_SDK_URL="$1"
FT_RUM_APP_ID="$2"
FT_APP_VERSION="$3"
FT_APP_ENV="$4"
DWARF_DSYM_FOLDER_PATH="$5"
SYMBOL_OUTPUT_PATH="$6"

run ${FT_SDK_URL} ${FT_RUM_APP_ID} ${FT_APP_VERSION} ${FT_APP_ENV} ${DWARF_DSYM_FOLDER_PATH} ${SYMBOL_OUTPUT_PATH}
fi
