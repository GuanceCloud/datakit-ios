#!/bin/bash

# Usage Examples (Command → Output XCFramework Name):
#   bash scripts/build-framework.sh GuanceSDK                                  → GuanceSDK.xcframework
#   bash scripts/build-framework.sh GuanceSDK --dynamic                        → GuanceSDK-Dynamic.xcframework
#   bash scripts/build-framework.sh GuanceSDK --disable-swizzling-resource     → GuanceSDK-DisableSwizzlingResource.xcframework
#   bash scripts/build-framework.sh GuanceSDK --dynamic --disable-swizzling-resource → GuanceSDK-Dynamic-DisableSwizzlingResource.xcframework
#   bash scripts/build-framework.sh GuanceWidgetExtension                      → GuanceWidgetExtension.xcframework
#   bash scripts/build-framework.sh GuanceSessionReplay                        → GuanceSessionReplay.xcframework
#   bash scripts/build-framework.sh GuanceSessionReplay --dynamic              → GuanceSessionReplay-Dynamic.xcframework

# Parameter Notes:
#   --dynamic: Build dynamic library (default: static library)
#   --disable-swizzling-resource: Disable URLSession method swizzling (avoids swizzling conflicts)

# SDK Usage Scenarios:
#   Main Project SDK: static/dynamic, iOS/tvOS/macOS
#   Widget Extension SDK: static only, iOS
#   Session Replay SDK: static/dynamic, iOS/macOS

# Output Path: Packaged SDK is saved to the repository "build" folder

set -euo pipefail
# ======================== CORE ========================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SWIZZLING_MACRO="FT_DISABLE_SWIZZLING_RESOURCE"
CONFIGURATION="Release"
PROJECT="${PROJECT:-${REPO_ROOT}/FTSDK.xcodeproj}"
BASE_CONFIG="${BASE_CONFIG:-${REPO_ROOT}/Base.xcconfig}"
XCODEBUILD_OPTIONS="${XCODEBUILD_OPTIONS--quiet}"

LIB_TYPE="static"
SCHEME_NAME=""
PRODUCT_NAME=""
WORK_DIR="${WORK_DIR:-${REPO_ROOT}/build}"
ARCHIVE_PLATFORMS=()

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
  local sdk_product_name
  local session_replay_product_name
  local widget_extension_product_name
  sdk_product_name="$(read_xcconfig_value_or_default SDK_PRODUCT_NAME GuanceSDK)"
  session_replay_product_name="$(read_xcconfig_value_or_default SESSION_REPLAY_PRODUCT_NAME GuanceSessionReplay)"
  widget_extension_product_name="$(read_xcconfig_value_or_default WIDGET_EXTENSION_PRODUCT_NAME GuanceWidgetExtension)"

  echo "Usage:"
  echo "  bash $0 <PRODUCT_NAME> [--dynamic] [--disable-swizzling-resource]"
  echo "  bash $0 <PRODUCT_NAME>-dynamic [--disable-swizzling-resource]"
  echo ""
  echo "Products:"
  echo "  ${sdk_product_name} (iOS/tvOS/macOS)"
  echo "  ${session_replay_product_name} (iOS)"
  echo "  ${widget_extension_product_name} (static only, iOS)"
  echo ""
  echo "Options:"
  echo "  --dynamic                       Build a dynamic XCFramework"
  echo "  --disable-swizzling-resource    Disable URLSession resource swizzling"
  echo ""
  echo "Examples:"
  echo "  bash $0 ${sdk_product_name}"
  echo "  bash $0 ${sdk_product_name} --dynamic"
  echo "  bash $0 ${sdk_product_name} --disable-swizzling-resource"
  echo "  bash $0 ${sdk_product_name} --dynamic --disable-swizzling-resource"
  echo "  bash $0 ${session_replay_product_name}"
  echo "  bash $0 ${session_replay_product_name} --dynamic"
  echo "  bash $0 ${widget_extension_product_name}"
  echo ""
  echo "Output:"
  echo "  build/<XCFrameworkName>/<XCFrameworkName>.xcframework"
}

# Check xcodebuild environment
check_env() {
  if ! command -v xcodebuild &> /dev/null; then
    error "❌ xcodebuild not found. Please install Xcode and configure command line tools"
  fi
  if [[ ! -d "${PROJECT}" ]]; then
    error "❌ Xcode project not found: ${PROJECT}"
  fi
  if [[ ! -f "${BASE_CONFIG}" ]]; then
    error "❌ Base xcconfig not found: ${BASE_CONFIG}"
  fi
  info "✅ Environment check passed"
}

read_xcconfig_value() {
  local key="$1"
  local value
  value=$(sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//p" "${BASE_CONFIG}" | tail -n 1)
  value="${value%%//*}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  if [[ -z "${value}" ]]; then
    error "❌ Missing ${key} in ${BASE_CONFIG}"
  fi
  echo "${value}"
}

read_xcconfig_value_or_default() {
  local key="$1"
  local fallback="$2"
  local value=""
  if [[ -f "${BASE_CONFIG}" ]]; then
    value=$(sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//p" "${BASE_CONFIG}" | tail -n 1)
    value="${value%%//*}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
  fi
  if [[ -z "${value}" ]]; then
    value="${fallback}"
  fi
  echo "${value}"
}

# Clean up old build artifacts (aligned with your script: empty build directory)
clean_build() {
  local clean="$1"
  info "🔍 Cleaning up old build artifacts: ${clean}"
  rm -rf "${clean}"
  mkdir -p "${clean}"
}

# Parse product input and map it to the neutral Xcode scheme.
# Parameter: product name
# Return: neutral scheme name and product name through globals
parse_product() {
  local product="$1"
  local product_lower=$(echo "${product}" | tr '[:upper:]' '[:lower:]')
  local requested_name
  if [[ "${product_lower}" == *"-dynamic" ]]; then
    LIB_TYPE="dynamic"
    requested_name="${product%-dynamic}"
  else
    requested_name="${product}"
  fi

  local sdk_product_name
  local session_replay_product_name
  local widget_extension_product_name
  sdk_product_name="$(read_xcconfig_value SDK_PRODUCT_NAME)"
  session_replay_product_name="$(read_xcconfig_value SESSION_REPLAY_PRODUCT_NAME)"
  widget_extension_product_name="$(read_xcconfig_value WIDGET_EXTENSION_PRODUCT_NAME)"

  if [[ "${requested_name}" == "FTSDK" || "${requested_name}" == "${sdk_product_name}" ]]; then
    SCHEME_NAME="FTSDK"
    PRODUCT_NAME="${sdk_product_name}"
  elif [[ "${requested_name}" == "FTSessionReplay" || "${requested_name}" == "${session_replay_product_name}" ]]; then
    SCHEME_NAME="FTSessionReplay"
    PRODUCT_NAME="${session_replay_product_name}"
  elif [[ "${requested_name}" == "FTWidgetExtension" || "${requested_name}" == "${widget_extension_product_name}" ]]; then
    SCHEME_NAME="FTWidgetExtension"
    PRODUCT_NAME="${widget_extension_product_name}"
  else
    error "❌ Unsupported product name: ${requested_name}. Run $0 --help to view supported products."
  fi

  if [[ "${SCHEME_NAME}" == "FTWidgetExtension" && "${LIB_TYPE}" == "dynamic" ]]; then
    error "❌ ${widget_extension_product_name} only supports static XCFrameworks. Remove --dynamic."
  fi
}

set_archive_platforms() {
  case "${SCHEME_NAME}" in
    FTSDK)
      ARCHIVE_PLATFORMS=("iphoneos" "iphonesimulator" "appletvos" "appletvsimulator" "macosx")
      ;;
    FTSessionReplay)
      ARCHIVE_PLATFORMS=("iphoneos" "iphonesimulator" "macosx")
      ;;
    FTWidgetExtension)
      ARCHIVE_PLATFORMS=("iphoneos" "iphonesimulator")
      ;;
    *)
      error "❌ Unsupported scheme for archive platforms: ${SCHEME_NAME}"
      ;;
  esac
}

platform_destination() {
  case "$1" in
    iphoneos)
      echo "generic/platform=iOS"
      ;;
    iphonesimulator)
      echo "generic/platform=iOS Simulator"
      ;;
    appletvos)
      echo "generic/platform=tvOS"
      ;;
    appletvsimulator)
      echo "generic/platform=tvOS Simulator"
      ;;
    macosx)
      echo "generic/platform=macOS"
      ;;
    *)
      error "❌ Unsupported archive platform: $1"
      ;;
  esac
}

framework_path_for_platform() {
  local archive_root="$1"
  local platform="$2"
  local product_name="$3"
  echo "${archive_root}/${platform}.xcarchive/Products/Library/Frameworks/${product_name}.framework"
}

dsym_path_for_platform() {
  local archive_root="$1"
  local platform="$2"
  local product_name="$3"
  echo "${archive_root}/${platform}.xcarchive/dSYMs/${product_name}.framework.dSYM"
}

# ======================== [Step 1: Compile Single Archive (aligned with your compilation logic)] ========================
# Parameter 1: Scheme name
# Parameter 2: Product name
# Parameter 3: Compilation platform (iphoneos/iphonesimulator/appletvos/appletvsimulator/macosx)
# Parameter 4: Whether to disable Swizzling (0/1)
# Parameter 5: Archive output path (e.g., ./build/ios.xcarchive)
build_archive() {
  local scheme="$1"
  local product_name="$2"
  local platform="$3"
  local disable_swizzling="$4"
  local archive_root="$5"
  local archive_path="${archive_root}/${platform}.xcarchive"
  local derived_data_path="${archive_root}/DerivedData/${platform}"
  local destination

  destination="$(platform_destination "${platform}")"

  info "📦 Starting to compile ${product_name} for ${platform} → ${archive_path} (${LIB_TYPE})"

  # Distinguish static/dynamic library parameters (aligned with your script)
  local mach_o_type="staticlib"
  if [[ "${LIB_TYPE}" == "dynamic" ]]; then
    mach_o_type="mh_dylib"
  fi

  # Preprocessor macros (Swizzling disable logic)
  local preprocessor_defs="\$(inherited)"
  if [[ "${disable_swizzling}" == "1" ]]; then
    preprocessor_defs+=" ${SWIZZLING_MACRO}=1"
  fi
  
  # Execute compilation (fully aligned with your xcodebuild parameters)
  # shellcheck disable=SC2086
  xcodebuild archive \
    ${XCODEBUILD_OPTIONS} \
    -project "${PROJECT}" \
    -scheme "${scheme}" \
    -configuration "${CONFIGURATION}" \
    -archivePath "${archive_path}" \
    -sdk "${platform}" \
    -destination "${destination}" \
    -derivedDataPath "${derived_data_path}" \
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
# Parameter 1: Product name
# Parameter 2: Framework output name
# Parameter 3: Archive path
create_xcframework() {
  local product_name="$1"
  local framework_name="$2"
  local ARCHIVE_PATH="$3"

  local create_args=()
  local platform
  local framework_path
  local dsym_path
  local XCF_FRAMEWORK_PATH="${ARCHIVE_PATH}/${framework_name}.xcframework"

  for platform in "${ARCHIVE_PLATFORMS[@]}"; do
    framework_path="$(framework_path_for_platform "${ARCHIVE_PATH}" "${platform}" "${product_name}")"
    if [[ ! -d "${framework_path}" ]]; then
      error "❌ Framework does not exist for ${platform}: ${framework_path}"
    fi
    create_args+=("-framework" "${framework_path}")

    if [[ "${LIB_TYPE}" == "dynamic" ]]; then
      dsym_path="$(dsym_path_for_platform "${ARCHIVE_PATH}" "${platform}" "${product_name}")"
      if [[ ! -d "${dsym_path}" ]]; then
        error "❌ dSYM does not exist for ${platform}: ${dsym_path}"
      fi
      create_args+=("-debug-symbols" "${dsym_path}")
    fi
  done


  # 4. Delete old XCFramework (avoid conflicts)
  rm -rf "${XCF_FRAMEWORK_PATH}"

  if [[ "${LIB_TYPE}" == "dynamic" ]]; then
    info  "\n📦 Generating xcframework (with standard path dSYM)..."
    xcodebuild -create-xcframework \
      "${create_args[@]}" \
      -output "${XCF_FRAMEWORK_PATH}"
    info "✅ Dynamic library XCFramework generated successfully: ${XCF_FRAMEWORK_PATH}"
  else
    info  "\n📦 Generating static library xcframework..."
    xcodebuild -create-xcframework \
      "${create_args[@]}" \
      -output "${XCF_FRAMEWORK_PATH}"
    info "✅ Static library xcframework generated successfully"
  fi

  if [[ ! -d "${XCF_FRAMEWORK_PATH}" ]]; then
    error "❌ XCFramework generation failed: ${XCF_FRAMEWORK_PATH} does not exist"
  fi
  if [[ ! -f "${XCF_FRAMEWORK_PATH}/Info.plist" ]]; then
    error "❌ Invalid XCFramework, Info.plist not found: ${XCF_FRAMEWORK_PATH}"
  fi
  
  for platform in "${ARCHIVE_PLATFORMS[@]}"; do
    rm -rf "${ARCHIVE_PATH}/${platform}.xcarchive"
  done
}

# ======================== [Main Workflow (strict step-by-step: clean → parse → compile → combine)] ========================
main() {
  # Initialize parameters
  local product=""
  local dynamic="0"
  local disable_swizzling="0"

  # Parse command line parameters (compatible with legacy commands)
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --scheme)
        if [[ $# -lt 2 ]]; then
          error "❌ Missing value for --scheme"
        fi
        product="$2"
        shift 2
        ;;
      --dynamic)
        dynamic="1"
        shift
        ;;
      --disable-swizzling-resource)
          disable_swizzling="1"
        shift
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        if [[ -z "${product}" ]]; then
          product="$1"
          shift
        else
          error "❌ Invalid parameter: $1 (Run $0 --help to view usage)"
        fi
        ;;
    esac
  done

  # Verify product name is mandatory
  if [[ -z "${product}" ]]; then
    error "❌ Missing product name! Run $0 --help to view usage."
  fi

  # Step 1: Environment check + clean up old artifacts
  check_env

  if [[ "${dynamic}" == "1" && "$(echo "${product}" | tr '[:upper:]' '[:lower:]')" != *"-dynamic" ]]; then
    product+="-dynamic"
  fi

  # Step 2: Parse product name (get neutral scheme name + framework name + library type)
  parse_product "${product}"
  set_archive_platforms
  
  local framework_name="${PRODUCT_NAME}"
  
  if [[ "${LIB_TYPE}" == "dynamic" ]]; then
          framework_name+="-Dynamic"
  fi
  if [[ "${disable_swizzling}" == "1" ]]; then
          framework_name+="-DisableSwizzlingResource"
  fi
  
  # Step 3
  mkdir -p "${WORK_DIR}"
  local archive_path="$(cd "${WORK_DIR}" && pwd)/${framework_name}"
  
  clean_build "${archive_path}"
  
  info "🔧  → PRODUCT_NAME: ${PRODUCT_NAME} | FRAMEWORK_NAME: ${framework_name} | LIB_TYPE: ${LIB_TYPE} | PLATFORMS: ${ARCHIVE_PLATFORMS[*]}"
  # Step 4: archive
  local platform
  for platform in "${ARCHIVE_PLATFORMS[@]}"; do
    build_archive "${SCHEME_NAME}" "${PRODUCT_NAME}" "${platform}" "${disable_swizzling}" "${archive_path}"
  done

  # Step 5: Combine archives to generate XCFramework (core: combine after compilation completes)
  create_xcframework "${PRODUCT_NAME}" "${framework_name}" "${archive_path}"
  rm -rf "${archive_path}/DerivedData"

  # Final artifact prompt
  info "🎉 Full workflow completed! Final artifact:"
  info "   → XCFramework: ${archive_path}/${framework_name}.xcframework"
}

# Execute main workflow
main "$@"
