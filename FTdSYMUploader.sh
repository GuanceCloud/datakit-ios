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
FT_APP_ID="<app_id>"
#datakit_address
FT_DATAKIT_ADDRESS="<datakit_address>"
# Environment field. Property values: prod/gray/pre/common/local. Must be consistent with SDK settings
FT_ENV="common"
# Token for dataway in the datakit.conf configuration file
FT_TOKEN="<dataway_token>"
# Whether to only generate dSYM zip file, 1=only package dSYM zip without upload, 0=upload, 
# you can search for FT_DSYM_ZIP_FILE in the script output log to view the DSYM_SYMBOL.zip file path
FT_DSYM_ZIP_ONLY=0

#
#
# Whether to upload in Debug mode compilation, 1=upload 0=no upload, default no upload
# UPLOAD_DEBUG_SYMBOLS=0
#
# # Whether to upload in simulator compilation, 1=upload 0=no upload, default no upload
# UPLOAD_SIMULATOR_SYMBOLS=0
#
# # Only upload during Archive operation, 1=support Archive upload 0=upload for all Release mode compilation
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
# # Command line input of basic application information
# # Upload symbol table files
# sh  FTdSYMUpload.sh <datakit_address> <app_id> <version> <env> <dataway_token> <dSYMBOL_src_dir>
# or
# # Only compress symbol table files
# sh  FTdSYMUpload.sh -dSYMFolderPath <dSYMBOL_src_dir> -z
#
#   Variable description:
#  - `<datakit_address>`: DataKit service address, such as `http://localhost:9529`
#  - `<app_id>`: Corresponds to RUM's `applicationId`
#  - `<env>`: Corresponds to RUM's `env`
#  - `<version>`: Application's `version`, `CFBundleShortVersionString` value
#  - `<dataway_token>`: Token for `dataway` in the `datakit.conf` configuration file
#  - `<dSYMBOL_src_dir>`: Path to the `dSYMBOL` folder to be uploaded
#  - `<dSYM_ZIP_ONLY>`: Whether to only package dSYM files into zip file. Optional. 
#    1=no upload, only package dSYM Zip, 0=upload, you can search for `FT_DSYM_ZIP_FILE` 
#    in the script output log to view the Zip file path
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
    P_BSYMBOL_ZIP_FILE="$1"
    P_DSYM_TEMPORARY_DIR="$2"

    #
    P_BSYMBOL_ZIP_FILE_NAME=${P_BSYMBOL_ZIP_FILE##*/}
    P_BSYMBOL_ZIP_FILE_NAME=${P_BSYMBOL_ZIP_FILE_NAME//&/_}
    P_BSYMBOL_ZIP_FILE_NAME="${P_BSYMBOL_ZIP_FILE_NAME// /_}"
    echo "P_BSYMBOL_ZIP_FILE_NAME: ${P_BSYMBOL_ZIP_FILE_NAME}"
    DSYM_UPLOAD_URL="${FT_DATAKIT_ADDRESS}/v1/sourcemap?app_id=${FT_APP_ID}&env=${FT_ENV}&version=${FT_VERSION}&platform=ios&token=${FT_TOKEN}"
    echo "dSYM upload url: ${DSYM_UPLOAD_URL}"
    
    echo "-----------------------------"
    STATUS=$(curl -X PUT "${DSYM_UPLOAD_URL}"  -F "file=@\"$P_BSYMBOL_ZIP_FILE\"")
    echo "-----------------------------"
    
    UPLOAD_RESULT="FAILTURE"
    echo "Upload server response: ${STATUS}"
    
    if [ ! "${STATUS}" ]; then
    echo "Error: Failed to upload the zip archive file."
    elif [[ "${STATUS}" == *"\"success\":true"* ]]; then
    echo "Success to upload the dSYM for the app [${P_APP_ENV} ${P_APP_VERSION}]"
    UPLOAD_RESULT="SUCCESS"
    else
    echo "Error: Failed to upload the zip archive file to DataKit."
    fi
    #Remove temp dSYM archive
    echo "Remove temporary DIR: ${P_DSYM_TEMPORARY_DIR}"
    rm -rf "${P_DSYM_TEMPORARY_DIR}"
    
    if [ "$?" -ne 0 ]; then
    exitWithMessage "Error: Failed to remove temporary zip archive." 0
    fi
    
    echo "--------------------------------"
    echo "Upload Result: ${UPLOAD_RESULT}."
    
    if [[ "${UPLOAD_RESULT}" == "FAILTURE" ]]; then
    echo "--------------------------------"
    echo "Failed to upload the dSYM"
    echo "Please check the script and try it again."
    fi
}

#Execute
function run() {
    CONFIG_DSYM_SOURCE_DIR="$1"
    CONFIG_DSYM_ZIP_ONLY="$2"
    
    if [ -z "$CONFIG_DSYM_ZIP_ONLY" ] || [ $CONFIG_DSYM_ZIP_ONLY -eq 0 ] ; then
    # Check if required parameters are set
    if [ ! "${FT_DATAKIT_ADDRESS}" ]; then
    exitWithMessage "Error: DATAKIT URL not defined." 0
    fi
    if [ ! "${FT_APP_ID}" ]; then
    exitWithMessage "Error: RUM App ID not defined." 0
    fi
   
    if [ ! "${FT_VERSION}" ]; then
    exitWithMessage "Error: App Version not defined." 0
    fi
    
    if [ ! "${FT_ENV}" ]; then
    exitWithMessage "Error: SDK Env not defined." 0
    fi
        if [ ! "${FT_TOKEN}" ]; then
    exitWithMessage "Error: Dataway Token not defined." 0
    fi
    
    echo "--------------------------------"
    echo "dSYM Upload information."
    echo "--------------------------------"
    
    
    echo "Datakit Url: ${FT_DATAKIT_ADDRESS}"
    echo "RUM App ID: ${FT_APP_ID}"
    echo "Dataway Token: ${FT_TOKEN}"
    echo "Version: ${FT_VERSION}"
    echo "Env: ${FT_ENV}"
    echo "DSYM FOLDER PATH: ${CONFIG_DSYM_SOURCE_DIR}"
    echo "--------------------------------"
    echo "Check the arguments ..."
    echo "--------------------------------"
    else
    echo "--------------------------------"
    echo "DSYM ZIP ONLY !!!"
    echo "DSYM FOLDER PATH: ${CONFIG_DSYM_SOURCE_DIR}"
    echo "--------------------------------"
    fi
    
    if [ ! -e "${CONFIG_DSYM_SOURCE_DIR}" ]; then
    exitWithMessage "Error: Invalid Source dir ${CONFIG_DSYM_SOURCE_DIR}" 0
    fi
    
    if [ ! "${CONFIG_DSYM_DEST_DIR}" ]; then
        CONFIG_DSYM_DEST_DIR=${CONFIG_DSYM_SOURCE_DIR}
    fi
    CONFIG_DSYM_DEST_DIR=${CONFIG_DSYM_DEST_DIR}/SymbolTemp
    # If the directory exists, force delete it .
    if [ -e "${CONFIG_DSYM_DEST_DIR}" ]; then
       rm -rf "${CONFIG_DSYM_DEST_DIR}"
    fi

    mkdir -p "${CONFIG_DSYM_DEST_DIR}"

    CONFIG_DSYM_DEST_DIR=$(realpath "$CONFIG_DSYM_DEST_DIR")

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
    
    echo "FT_DSYM_ZIP_FILE:${DSYM_SYMBOL_ZIP_FILE}"

    if [ -e $DSYM_SYMBOL_ZIP_FILE ]; then
    rm -f $DSYM_SYMBOL_ZIP_FILE
    fi
    # Compress dSYM directory
    pushd $CONFIG_DSYM_DEST_DIR
    zip -r -q $DSYM_SYMBOL_ZIP_FILE *
    popd
    
    if [ $CONFIG_DSYM_ZIP_ONLY -eq 0 ]; then
    # Upload
    dSYMUpload "$DSYM_SYMBOL_ZIP_FILE" "$CONFIG_DSYM_DEST_DIR"
    if [ $RET = "F" ]; then
    exitWithMessage "No .dSYM found in ${DSYM_FOLDER}" 0
    fi
    fi
    fi
}
# Check if the app's dSYM file is empty, if empty, wait in a loop for 10s, 
# if still empty then exit
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
    FT_VERSION="${BUNDLE_SHORT_VERSION}"
    fi
    
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
    run ${DWARF_DSYM_FOLDER_PATH} ${FT_DSYM_ZIP_ONLY}
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
echo "\nUsage: dSYMUpload.sh <sdk_url> <rum_app_id> <app_version> <app_env> <dataway_token> <dSYMBOL_src_dir> <dSYMBOL_dest_dir>\n or dSYMUpload.sh -dSYMFolderPath <dSYMBOL_src_dir> -z"

max_args=6
if [ $# -ge $max_args ]; then
    FT_DATAKIT_ADDRESS="$1"
    FT_APP_ID="$2"
    FT_VERSION="$3"
    FT_ENV="$4"
    FT_TOKEN="$5"
    DWARF_DSYM_FOLDER_PATH="$6"
    FT_DSYM_ZIP_ONLY=${7:-"0"}
else
while [[ $# -gt 0 ]]; do
    key="$1"
    case ${key} in
        -url)
        FT_DATAKIT_ADDRESS="$2"
        shift
        shift
        ;;
        -appid)
        FT_APP_ID="$2"
        shift
        shift
        ;;
        -version)
        FT_VERSION="$2"
        shift
        shift
        ;;
        -env)
        FT_ENV="$2"
        shift
        shift
        ;;
        -token)
        FT_TOKEN="$2"
        shift
        shift
        ;;
        -dSYMFolderPath)
        DWARF_DSYM_FOLDER_PATH="$2"
        shift # past argument
        shift # past value
        ;;
        -z)
        FT_DSYM_ZIP_ONLY=1
        shift # past argument
        ;;
        *)
        # Ignore unknown parameters or report error
        shift
        ;;
    esac
done

fi

run "$DWARF_DSYM_FOLDER_PATH" ${FT_DSYM_ZIP_ONLY}
fi
