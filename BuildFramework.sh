# Example: sh BuildFramework.sh FTMobileSDK
# Note: All without dynamic suffix are static libraries
# SDK required by main project: FTMobileSDK, FTMobileSDK-dynamic
# SDK required by Widget Extension: FTMobileExtension
# The packaged SDK is stored in the build folder under the current directory

set -euo pipefail

buildFrameWorkWithName(){
    SCHEME_NAME="$1"
    # Force escape special characters in path (critical fix)
    WORK_DIR="$(cd "$(dirname "./build/${SCHEME_NAME}")" && pwd)/$(basename "./build/${SCHEME_NAME}")"
    # Delete old directory first (avoid cache) then recreate it
    rm -rf "${WORK_DIR}"
    mkdir -p "${WORK_DIR}"

    if [[ "${SCHEME_NAME}" == *dynamic* ]]; then
        FRAMEWORK_NAME="${SCHEME_NAME/-dynamic/}"  # Remove '-dynamic' suffix
        echo "SCHEME_NAME (${SCHEME_NAME}) contains 'dynamic', this is a dynamic library"
        IS_DYNAMIC_FRAMEWORK=true
    else
        FRAMEWORK_NAME="${SCHEME_NAME}"
        echo "SCHEME_NAME (${SCHEME_NAME}) does not contain 'dynamic', this is a static library"
        IS_DYNAMIC_FRAMEWORK=false
    fi

    ## 1. Archive iOS device build (add dSYM compilation flags for dynamic libraries)
    echo "📦 Starting iOS device archive..."
    xcodebuild archive \
      -scheme "${SCHEME_NAME}" \
      -configuration Release \
      -archivePath "${WORK_DIR}/ios.xcarchive" \
      -sdk iphoneos \
      SKIP_INSTALL=NO \
      BUILD_LIBRARY_FOR_DISTRIBUTION=YES

    ## 2. Archive iOS simulator build (add dSYM compilation flags for dynamic libraries)
    echo "📦 Starting iOS simulator archive..."
    xcodebuild archive \
      -scheme "${SCHEME_NAME}" \
      -configuration Release \
      -archivePath "${WORK_DIR}/ios-sim.xcarchive" \
      -sdk iphonesimulator \
      SKIP_INSTALL=NO \
      BUILD_LIBRARY_FOR_DISTRIBUTION=YES
      
    ## 3. Dynamic library processing: Force validate dSYM and generate xcframework
    if [ "${IS_DYNAMIC_FRAMEWORK}" = true ]; then
        # Explicitly specify dSYM path (path you confirmed exists)
        IOS_DSYM_ACTUAL="${WORK_DIR}/ios.xcarchive/dSYMs/${FRAMEWORK_NAME}.framework.dSYM"
        SIM_DSYM_ACTUAL="${WORK_DIR}/ios-sim.xcarchive/dSYMs/${FRAMEWORK_NAME}.framework.dSYM"

        # Force validate dSYM file (print detailed information)
        echo  "\n🔍 Validating dSYM file existence:"
        if [ -d "${IOS_DSYM_ACTUAL}" ]; then
            echo "✅ iOS device dSYM exists: ${IOS_DSYM_ACTUAL}"
            # Print dSYM detailed info to confirm it's a valid file
            dwarfdump --uuid "${IOS_DSYM_ACTUAL}" || echo "⚠️ iOS device dSYM may be corrupted, but path exists"
        else
            echo "❌ iOS device dSYM does not exist: ${IOS_DSYM_ACTUAL}"
            exit 1
        fi

        if [ -d "${SIM_DSYM_ACTUAL}" ]; then
            echo "✅ iOS simulator dSYM exists: ${SIM_DSYM_ACTUAL}"
            dwarfdump --uuid "${SIM_DSYM_ACTUAL}" || echo "⚠️ iOS simulator dSYM may be corrupted, but path exists"
        else
            echo "❌ iOS simulator dSYM does not exist: ${SIM_DSYM_ACTUAL}"
            exit 1
        fi

        ## 4. Generate xcframework (critical: wrap all paths in double quotes to avoid parsing errors)
        echo  "\n📦 Generating xcframework (with standard path dSYM)..."
        XCF_FRAMEWORK_PATH="${WORK_DIR}/${FRAMEWORK_NAME}.xcframework"
        
        # Split command into multiple lines to avoid parsing errors from overly long parameters
        xcodebuild -create-xcframework \
          -framework "${WORK_DIR}/ios.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework" \
          -debug-symbols "${IOS_DSYM_ACTUAL}" \
          -framework "${WORK_DIR}/ios-sim.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework" \
          -debug-symbols "${SIM_DSYM_ACTUAL}" \
          -output "${XCF_FRAMEWORK_PATH}"

    else
        # Static library: Only generate xcframework, no dSYM processing
        echo  "\n📦 Generating static library xcframework..."
        XCF_FRAMEWORK_PATH="${WORK_DIR}/${FRAMEWORK_NAME}.xcframework"
        xcodebuild -create-xcframework \
          -framework "${WORK_DIR}/ios.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework" \
          -framework "${WORK_DIR}/ios-sim.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework" \
          -output "${XCF_FRAMEWORK_PATH}"
        echo "✅ Static library xcframework generated successfully"
    fi

    echo "\n✅ Final xcframework path: ${XCF_FRAMEWORK_PATH}"
    echo "--------------END--------------"
}
echo "--------------START--------------"
# Validate input parameter
if [ -z "$1" ]; then
    echo "❌ Error: Please provide SCHEME_NAME, example: sh BuildFramework.sh FTMobileSDK"
    exit 1
fi
echo "SCHEME_NAME: $1"

buildFrameWorkWithName "$1"
