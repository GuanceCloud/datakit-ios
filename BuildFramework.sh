# Usage Examples (Command → Output XCFramework Name):
#   sh BuildFramework.sh FTMobileSDK                          → FTMobileSDK.xcframework
#   sh BuildFramework.sh FTMobileSDK-dynamic                  → FTMobileSDK-Dynamic.xcframework
#   sh BuildFramework.sh FTMobileSDK --disable-swizzling-resource  → FTMobileSDK-DisableSwizzlingResource.xcframework
#   sh BuildFramework.sh FTMobileSDK-dynamic --disable-swizzling-resource → FTMobileSDK-Dynamic-DisableSwizzlingResource.xcframework
#   sh BuildFramework.sh FTMobileExtension                    → FTMobileExtension.xcframework
#   sh BuildFramework.sh FTMobileExtension --disable-swizzling-resource → FTMobileExtension-DisableSwizzlingResource.xcframework

# Parameter Notes:
#   -dynamic: Build dynamic library (default: static library)
#   --disable-swizzling-resource: Disable URLSession method swizzling (avoids swizzling conflicts)

# SDK Usage Scenarios:
#   Main Project: FTMobileSDK (static/dynamic)
#   Widget Extension: FTMobileExtension (static only) / FTMobileSDK-dynamic (dynamic, shared with main project)

# Output Path: Packaged SDK is saved to the "build" folder in the current directory

set -euo pipefail
#!/bin/bash
# ======================== CORE ========================
SWIZZLING_MACRO="FT_DISABLE_SWIZZLING_RESOURCE"
CONFIGURATION="Release"
DEFAULT_DISABLE_SWIZZLING="0"

LIB_TYPE="static"
SCHEME_NAME=""
WORK_DIR="./build"

# ======================== [Utility Functions] ========================
# Output logs to stderr to avoid polluting path outputs
info() {
  echo -e "\033[32m[INFO] $1\033[0m" >&2
}

error() {
  echo -e "\033[31m[ERROR] $1\033[0m" >&2
  exit 1
}

show_help() {
  echo "Usage:"
  echo "  sh $0 <SCHEME_NAME> [--disable-swizzling-resource]"
  echo ""
  echo "Core Workflow (aligned with original script):"
  echo "  1. Compile archive for physical iOS devices"
  echo "  2. Compile archive for iOS simulators"
  echo "  3. Combine two archives to generate XCFramework (dynamic libraries link dSYM files)"
  echo ""
  echo "Examples:"
  echo " sh $0 FTMobileSDK-dynamic --disable-swizzling-resource # dynamic + disable swizzling"
  echo " sh $0 FTMobileSDK # static + disable swizzling"
}

# Check xcodebuild environment
check_env() {
  if ! command -v xcodebuild &> /dev/null; then
    error "❌ xcodebuild not found. Please install Xcode and configure command line tools"
  fi
  info "✅ Environment check passed"
}

# Clean up old build artifacts (aligned with your script: empty build directory)
clean_build() {
  local clean="$1"
  info "🔍 Cleaning up old build artifacts: ${clean}"
  rm -rf "${clean}"
  mkdir -p "${clean}"
}

# Parse Scheme (core: distinguish static/dynamic libraries, return framework name)
# Parameter: scheme name
# Return: framework name (stdout) + library type (static/dynamic, global variable LIB_TYPE)
parse_scheme() {
  local scheme="$1"
  local scheme_lower=$(echo "${scheme}" | tr '[:upper:]' '[:lower:]')
  if [[ "${scheme_lower}" == *"-dynamic" ]]; then
    LIB_TYPE="dynamic"
    SCHEME_NAME="${scheme%%-*}"
  else
    LIB_TYPE="static"
    SCHEME_NAME="${scheme}"
  fi
}

# ======================== [Step 1: Compile Single Archive (aligned with your compilation logic)] ========================
# Parameter 1: Scheme name
# Parameter 2: Framework name
# Parameter 3: Compilation platform (iphoneos/iphonesimulator)
# Parameter 4: Whether to disable Swizzling (0/1)
# Parameter 5: Archive output path (e.g., ./build/ios.xcarchive)
build_archive() {
  local scheme="$1"
  local framework_name="$2"
  local platform="$3"
  local disable_swizzling="$4"
  local archive_path="$5"
  
  archive_path+="/${platform}.xcarchive"
  
  info "📦 Starting to compile ${platform} archive → ${archive_path} (${LIB_TYPE})"

  # Distinguish static/dynamic library parameters (aligned with your script)
  local mach_o_type="staticlib"
  local build_lib_for_dist="NO"
  if [[ "${LIB_TYPE}" == "dynamic" ]]; then
    mach_o_type="mh_dylib"
  fi

  # Preprocessor macros (Swizzling disable logic)
  local preprocessor_defs="\$(inherited)"
  local active_compile_conditions="\$(inherited)"
  if [[ "${disable_swizzling}" == "1" ]]; then
    preprocessor_defs+=" ${SWIZZLING_MACRO}=1"
  fi
  
  # Execute compilation (fully aligned with your xcodebuild parameters)
  xcodebuild archive \
    -scheme "${scheme}" \
    -configuration "${CONFIGURATION}" \
    -archivePath "${archive_path}" \
    -sdk "${platform}" \
    SKIP_INSTALL=NO \
    MACH_O_TYPE="${mach_o_type}" \
    GCC_PREPROCESSOR_DEFINITIONS="${preprocessor_defs}" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES
    
  # Verify if archive was generated successfully
  if [[ ! -d "${archive_path}" ]]; then
    error "❌ ${platform} archive compilation failed: ${archive_path} does not exist"
  fi
  info "✅ ${platform} archive compiled successfully"
}

# ======================== [Step 2: Combine XCFramework (fully replicate your logic)] ========================
# Parameter 1: Framework name
# Parameter 2: Whether to disable Swizzling (0/1)
# Parameter 3: Archive path
create_xcframework() {
  local scheme="$1"
  local framework_name="$2"
  local ARCHIVE_PATH="$3"

  local ios_framework="${ARCHIVE_PATH}/iphoneos.xcarchive/Products/Library/Frameworks/${scheme}.framework"
  local sim_framework="${ARCHIVE_PATH}/iphonesimulator.xcarchive/Products/Library/Frameworks/${scheme}.framework"
 
  local XCF_FRAMEWORK_PATH="${ARCHIVE_PATH}/${framework_name}.xcframework"
  
  # 2. Verify framework path validity
  if [[ ! -d "${ios_framework}" ]]; then
    error "❌ Physical device Framework does not exist: ${ios_framework}"
  fi
  if [[ ! -d "${sim_framework}" ]]; then
    error "❌ Simulator Framework does not exist: ${sim_framework}"
  fi
  
  # 4. Delete old XCFramework (avoid conflicts)
  rm -rf "${XCF_FRAMEWORK_PATH}"

  # 5. Generate XCFramework (fully replicate your branch logic)
  if [[ "${LIB_TYPE}" == "dynamic" ]]; then
    local ios_dsym="${ARCHIVE_PATH}/iphoneos.xcarchive/dSYMs/${scheme}.framework.dSYM"
    local sim_dsym="${ARCHIVE_PATH}/iphonesimulator.xcarchive/dSYMs/${scheme}.framework.dSYM"
 
    info  "\n📦 Generating xcframework (with standard path dSYM)..."
    # Dynamic library: use -debug-symbols parameter (your core logic)
    xcodebuild -create-xcframework \
          -framework "${ios_framework}" \
          -debug-symbols "${ios_dsym}" \
          -framework "${sim_framework}" \
          -debug-symbols "${sim_dsym}" \
          -output "${XCF_FRAMEWORK_PATH}"
    info "✅ Dynamic library XCFramework generated successfully: ${XCF_FRAMEWORK_PATH}"
  else
    # Static library: only combine frameworks, no dSYM files
    info  "\n📦 Generating static library xcframework..."
    xcodebuild -create-xcframework \
      -framework "${ios_framework}" \
      -framework "${sim_framework}" \
      -output "${XCF_FRAMEWORK_PATH}"
    info "✅ Static library xcframework generated successfully"
  fi
  
  rm -rf "${ARCHIVE_PATH}/iphoneos.xcarchive"
  rm -rf "${ARCHIVE_PATH}/iphonesimulator.xcarchive"
}

# ======================== [Main Workflow (strict step-by-step: clean → parse → compile → combine)] ========================
main() {
  # Initialize parameters
  local scheme=""
  local disable_swizzling="0"

  # Parse command line parameters (compatible with legacy commands)
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --scheme)
        scheme="$2"
        shift 2
        ;;
      --disable-swizzling-resource)
          disable_swizzling="1"
        shift
        ;;
      --help)
        show_help
        exit 0
        ;;
      *)
        if [[ -z "${scheme}" ]]; then
          scheme="$1"
          shift
        else
          error "❌ Invalid parameter: $1 (Run $0 --help to view usage)"
        fi
        ;;
    esac
  done

  # Verify Scheme is mandatory
  if [[ -z "${scheme}" ]]; then
    error "❌ Missing Scheme name! Example: $0 FTMobileSDK-dynamic"
  fi

  # Step 1: Environment check + clean up old artifacts
  check_env

  # Step 2: Parse Scheme (get framework name + library type)
  parse_scheme "${scheme}"
  
  local framework_name="${SCHEME_NAME}"
  
  if [[ "${LIB_TYPE}" == "dynamic" ]]; then
          framework_name+="-Dynamic"
  fi
  if [[ "${disable_swizzling}" == "1" ]]; then
          framework_name+="-DisableSwizzlingResource"
  fi
  
  # Step 3
  local archive_path="$(cd "$(dirname "${WORK_DIR}/${framework_name}")" && pwd)/$(basename "${WORK_DIR}/${framework_name}")"
  
  clean_build "${archive_path}"
  
  info "🔧  → SCHEME_NAME: ${SCHEME_NAME} | FRAMEWORK_NAME: ${framework_name} | LIB_TYPE: ${LIB_TYPE}"
  # Step 4: archive
  build_archive "${SCHEME_NAME}" "${framework_name}" "iphoneos" "${disable_swizzling}" "${archive_path}"
  build_archive "${SCHEME_NAME}" "${framework_name}" "iphonesimulator" "${disable_swizzling}" "${archive_path}"

  # Step 5: Combine archives to generate XCFramework (core: combine after compilation completes)
  create_xcframework "${SCHEME_NAME}" "${framework_name}" "${archive_path}"

  # Final artifact prompt
  info "🎉 Full workflow completed! Final artifact:"
  info "   → XCFramework: ${archive_path}/${SCHEME_NAME}.xcframework"
}

# Execute main workflow
main "$@"
