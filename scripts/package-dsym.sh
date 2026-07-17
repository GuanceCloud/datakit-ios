#!/bin/bash
#
# This script packages iOS dSYM files into a zip archive.
#
######################################################
# 1. Script integration into Xcode project Target
######################################################
#
# --- Copy one of the examples below to the Run Script of Build Phases ---
#
# # Whether to package in Debug mode compilation, 1=package 0=no package, default no package
# PACKAGE_DEBUG_SYMBOLS=0
#
# # Whether to package in simulator compilation, 1=package 0=no package, default no package
# PACKAGE_SIMULATOR_SYMBOLS=0
#
# # Only package during Archive operation, 1=support Archive package 0=package for all Release mode compilation
# PACKAGE_ARCHIVE_ONLY=1
#
# # Xcode builds output the zip to SRCROOT/FTdSYMSymbols by default.
# # Set CONFIG_DSYM_DEST_DIR to override the zip output directory.
#
# # Example 1: package dSYM only.
# # Adjust the path if package-dsym.sh is not in SRCROOT/scripts.
# FT_DSYM_PACKAGER="${SRCROOT}/scripts/package-dsym.sh"
# if [ -f "${FT_DSYM_PACKAGER}" ]; then
# bash "${FT_DSYM_PACKAGER}"
# else
# echo "error: package-dsym.sh not found at ${FT_DSYM_PACKAGER}"
# fi
#
# --- END OF SCRIPT ---
#
#
#######################################################
# 2. Script processing based on input parameters
#######################################################
#
# Package symbol table files:
# bash scripts/package-dsym.sh <dSYMBOL_src_dir>
# or
# bash scripts/package-dsym.sh -dSYMFolderPath <dSYMBOL_src_dir>
#
# Optional:
# bash scripts/package-dsym.sh -dSYMFolderPath <dSYMBOL_src_dir> -version <app_version>
#
# Search for FT_DSYM_ZIP_FILE in Xcode logs to view the generated zip file path.
# The last output line is also the raw generated zip file path.
#
# The generated zip can be uploaded manually or passed to Guance's OpenAPI
# sourcemap upload script:
# https://docs.guance.com/real-user-monitoring/sourcemap/script-upload-sourcemap/#sourcemap
#
# When using Guance's upload-sourcemap.sh, the generated zip can be used as
# the official upload script's --file value.
#

PACKAGE_DEBUG_SYMBOLS=${PACKAGE_DEBUG_SYMBOLS:-0}
PACKAGE_SIMULATOR_SYMBOLS=${PACKAGE_SIMULATOR_SYMBOLS:-0}
PACKAGE_ARCHIVE_ONLY=${PACKAGE_ARCHIVE_ONLY:-1}
FT_DSYM_OUTPUT_DIR_NAME=${FT_DSYM_OUTPUT_DIR_NAME:-FTdSYMSymbols}

function exitWithMessage(){
    echo "--------------------------------"
    echo "${1}"
    echo "--------------------------------"
    exit "${2}"
}

function printUsage(){
    echo "Usage: scripts/package-dsym.sh <dSYMBOL_src_dir>"
    echo "   or: scripts/package-dsym.sh -dSYMFolderPath <dSYMBOL_src_dir> [-version <app_version>]"
}

function sanitizeFileNamePart(){
    local value="$1"
    value="${value//&/_}"
    value="${value// /_}"
    value="${value//\//_}"
    value="${value//:/_}"
    echo "${value}"
}

function absolutePath(){
    local path="$1"
    if [ -d "${path}" ]; then
        (cd "${path}" && pwd -P)
    else
        local dir
        local base
        dir="$(dirname "${path}")"
        base="$(basename "${path}")"
        echo "$(cd "${dir}" && pwd -P)/${base}"
    fi
}

function packageDSYM(){
    local source_dir="$1"
    local app_version="$2"
    local source_dir_abs
    local output_dir
    local temp_dir
    local zip_name
    local zip_file
    local found_dsym="F"

    if [ ! -e "${source_dir}" ]; then
        exitWithMessage "Error: Invalid Source dir ${source_dir}" 0
    fi

    source_dir_abs="$(absolutePath "${source_dir}")"
    if [ "${CONFIG_DSYM_DEST_DIR}" ]; then
        output_dir="${CONFIG_DSYM_DEST_DIR}"
    elif [[ "$(basename "${source_dir_abs}")" == *.dSYM ]]; then
        output_dir="$(dirname "${source_dir_abs}")/${FT_DSYM_OUTPUT_DIR_NAME}"
    else
        output_dir="${source_dir_abs}/${FT_DSYM_OUTPUT_DIR_NAME}"
    fi

    mkdir -p "${output_dir}"
    output_dir="$(absolutePath "${output_dir}")"

    temp_dir="${output_dir}/SymbolTemp"
    if [ -e "${temp_dir}" ]; then
        rm -rf "${temp_dir}"
    fi

    mkdir -p "${temp_dir}"
    temp_dir="$(absolutePath "${temp_dir}")"

    echo "--------------------------------"
    echo "dSYM package information."
    echo "DSYM FOLDER PATH: ${source_dir_abs}"
    echo "ZIP OUTPUT DIR: ${output_dir}"
    if [ "${app_version}" ]; then
        echo "Version: ${app_version}"
    fi
    echo "--------------------------------"
    echo "Scanning dSYM FOLDER: ${source_dir_abs} ..."

    if [[ "$(basename "${source_dir_abs}")" == *.dSYM ]]; then
        found_dsym="T"
        echo "Found dSYM file: ${source_dir_abs}"
        cp -R "${source_dir_abs}" "${temp_dir}/"
    else
        while IFS= read -r -d '' dsym_file; do
            found_dsym="T"
            echo "Found dSYM file: ${dsym_file}"
            cp -R "${dsym_file}" "${temp_dir}/"
        done < <(find "${source_dir_abs}" -type d -name 'SymbolTemp' -prune -o -name '*.dSYM' -print0)
    fi

    if [ "${found_dsym}" = "F" ]; then
        exitWithMessage "No .dSYM found in ${source_dir_abs}" 0
    fi

    if [ "${app_version}" ]; then
        zip_name="DSYM_SYMBOL_$(sanitizeFileNamePart "${app_version}").zip"
    else
        zip_name="DSYM_SYMBOL.zip"
    fi

    zip_file="${output_dir}/${zip_name}"
    if [ -e "${zip_file}" ]; then
        rm -f "${zip_file}"
    fi

    (
        cd "${temp_dir}" || exit 1
        zip -r -q "${zip_file}" ./*.dSYM
    )

    if [ "$?" -ne 0 ]; then
        exitWithMessage "Error: Failed to package dSYM files." 0
    fi

    rm -rf "${temp_dir}"
    echo "FT_DSYM_ZIP_FILE:${zip_file}"
    echo "Package Result: SUCCESS."
    echo "${zip_file}"
}

# Check if the app's dSYM file is empty, if empty, wait in a loop for 10s,
# if still empty then exit.
function checkAppSourceFile(){
    local app_dsym_file="$1"
    local i
    for i in {1..10}; do
        if [ -s "${app_dsym_file}" ]; then
            return 0
        fi
        sleep 1
    done
    return 1
}

function resolveInfoPlistFile(){
    if [ -f "${INFOPLIST_FILE}" ]; then
        echo "${INFOPLIST_FILE}"
        return
    fi

    if [ "${SRCROOT}" ] && [ -f "${SRCROOT}/${INFOPLIST_FILE}" ]; then
        echo "${SRCROOT}/${INFOPLIST_FILE}"
        return
    fi

    echo "${INFOPLIST_FILE}"
}

function readBundleShortVersion(){
    local info_plist="$1"
    local bundle_short_version=""

    if [ -f "${info_plist}" ]; then
        bundle_short_version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "${info_plist}" 2>/dev/null)
    fi

    if [[ "${bundle_short_version}" == *"MARKETING_VERSION"* ]]; then
        bundle_short_version="${MARKETING_VERSION}"
    fi

    echo "${bundle_short_version}"
}

function runInXcode(){
    local info_plist
    local bundle_short_version
    local dsym_file
    local file_name
    local app_dsym_file
    local check_result

    echo "Packaging dSYM in Xcode ..."

    info_plist="$(resolveInfoPlistFile)"
    echo "Info.Plist : ${info_plist}"

    bundle_short_version="$(readBundleShortVersion "${info_plist}")"
    echo "BUNDLE_SHORT_VERSION: ${bundle_short_version}"

    if [ "$EFFECTIVE_PLATFORM_NAME" == "-iphonesimulator" ]; then
        if [ "${PACKAGE_SIMULATOR_SYMBOLS}" -eq 0 ]; then
            exitWithMessage "Warning: Build for simulator and skipping to package. \nYou can modify 'PACKAGE_SIMULATOR_SYMBOLS' to 1 in the script." 0
        fi
    fi

    if [ "${CONFIGURATION=}" == "Debug" ]; then
        if [ "${PACKAGE_DEBUG_SYMBOLS}" -eq 0 ]; then
            exitWithMessage "Warning: Build for debug mode and skipping to package. \nYou can modify 'PACKAGE_DEBUG_SYMBOLS' to 1 in the script." 0
        fi
    fi

    if [ "${PACKAGE_ARCHIVE_ONLY}" -eq 1 ]; then
        if [[ "$TARGET_BUILD_DIR" == *"/Archive"* ]]; then
            echo "Archive the package"
        else
            exitWithMessage "Warning: Build for NOT Archive mode and skipping to package. \nYou can modify 'PACKAGE_ARCHIVE_ONLY' to 0 in the script." 0
        fi
    fi

    while IFS= read -r -d '' dsym_file; do
        file_name=${dsym_file##*/}
        file_name="$(sanitizeFileNamePart "${file_name}")"
        if [[ "${file_name}" == "${PRODUCT_NAME}"* ]]; then
            app_dsym_file="${dsym_file}/Contents/Resources/DWARF/${PRODUCT_NAME}"
            checkAppSourceFile "${app_dsym_file}"
            check_result=$?
            echo "checkAppSourceFile: ${check_result}"
            if [ "${check_result}" -eq 1 ]; then
                exitWithMessage "Not Found File In ${app_dsym_file}" 0
            fi
        fi
    done < <(find "${DWARF_DSYM_FOLDER_PATH}" -name '*.dSYM' -print0)

    if [ -z "${CONFIG_DSYM_DEST_DIR}" ] && [ "${SRCROOT}" ]; then
        CONFIG_DSYM_DEST_DIR="${SRCROOT}/${FT_DSYM_OUTPUT_DIR_NAME}"
    fi

    packageDSYM "${DWARF_DSYM_FOLDER_PATH}" "${bundle_short_version}"
}

function parseCommandLine(){
    if [ "$#" -eq 0 ]; then
        printUsage
        exit 0
    fi

    if [ "$#" -eq 1 ] && [ -e "$1" ]; then
        DWARF_DSYM_FOLDER_PATH="$1"
        return
    fi

    # Compatibility with the old FTdSYMUploader.sh positional arguments.
    # The app version is argument 3 and the dSYM folder path is argument 6.
    if [ "$#" -ge 6 ] && [ -e "$6" ]; then
        FT_VERSION="$3"
        DWARF_DSYM_FOLDER_PATH="$6"
        return
    fi

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -version)
                FT_VERSION="$2"
                shift
                shift
                ;;
            -dSYMFolderPath)
                DWARF_DSYM_FOLDER_PATH="$2"
                shift
                shift
                ;;
            -dSYMDestPath)
                CONFIG_DSYM_DEST_DIR="$2"
                shift
                shift
                ;;
            -z)
                shift
                ;;
            -url|-appid|-env|-token)
                shift
                shift
                ;;
            *)
                if [ -z "${DWARF_DSYM_FOLDER_PATH}" ] && [ -e "$1" ]; then
                    DWARF_DSYM_FOLDER_PATH="$1"
                fi
                shift
                ;;
        esac
    done
}

INFO_PLIST_FILE="${INFOPLIST_FILE}"
BuildInXcode="F"
if [ -f "${INFO_PLIST_FILE}" ]; then
    BuildInXcode="T"
elif [ "${SRCROOT}" ] && [ -f "${SRCROOT}/${INFO_PLIST_FILE}" ]; then
    BuildInXcode="T"
fi

if [ "${BuildInXcode}" = "T" ]; then
    runInXcode
else
    parseCommandLine "$@"
    if [ -z "${DWARF_DSYM_FOLDER_PATH}" ]; then
        printUsage
        exitWithMessage "Error: dSYM folder path not defined." 0
    fi
    packageDSYM "${DWARF_DSYM_FOLDER_PATH}" "${FT_VERSION}"
fi
