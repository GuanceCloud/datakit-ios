#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_SCRIPT="${SCRIPT_DIR}/BuildFramework.sh"
BUILD_DIR="${SCRIPT_DIR}/build"
STAGING_DIR="${BUILD_DIR}/.SDKPackageStaging"
STATIC_DIR="${STAGING_DIR}/SDK-Static"
DYNAMIC_DIR="${STAGING_DIR}/SDK-Dynamic"
SDK_ZIP="${BUILD_DIR}/SDK.zip"

INTERMEDIATE_DIRS=(
  "FTMobileSDK"
  "FTMobileSDK-Dynamic"
  "FTMobileSDK-DisableSwizzlingResource"
  "FTMobileSDK-Dynamic-DisableSwizzlingResource"
  "FTSessionReplay"
  "FTSessionReplay-Dynamic"
  "FTMobileExtension"
  "FTMobileExtension-DisableSwizzlingResource"
)

info() {
  echo "[INFO] $1"
}

error() {
  echo "[ERROR] $1" >&2
  exit 1
}

show_help() {
  echo "Usage:"
  echo "  bash $0"
  echo ""
  echo "Output:"
  echo "  build/SDK.zip"
  echo ""
  echo "Unzip structure:"
  echo "  SDK-Static/*.xcframework"
  echo "  SDK-Dynamic/*.xcframework"
}

cleanup_temp_files() {
  rm -rf "${STAGING_DIR}"
  rm -rf "${BUILD_DIR}/FTSDK-static" "${BUILD_DIR}/FTSDK-dynamic"
  rm -f "${BUILD_DIR}/FTSDK-static.zip" "${BUILD_DIR}/FTSDK-dynamic.zip"

  local dir_name
  for dir_name in "${INTERMEDIATE_DIRS[@]}"; do
    rm -rf "${BUILD_DIR}/${dir_name}"
  done
}

check_env() {
  if [[ ! -f "${BUILD_SCRIPT}" ]]; then
    error "Build script not found: ${BUILD_SCRIPT}"
  fi

  if ! command -v zip > /dev/null 2>&1; then
    error "zip not found. Please install zip first."
  fi

  if ! command -v zipinfo > /dev/null 2>&1; then
    error "zipinfo not found. Please install zipinfo first."
  fi
}

prepare_output() {
  mkdir -p "${BUILD_DIR}"
  rm -f "${SDK_ZIP}"
  cleanup_temp_files
  mkdir -p "${STATIC_DIR}" "${DYNAMIC_DIR}"
}

build_and_copy() {
  local build_scheme="$1"
  local source_name="$2"
  local package_dir="$3"
  local destination_name="$4"
  shift 4

  local source_path="${BUILD_DIR}/${source_name}/${source_name}.xcframework"
  local destination_path="${package_dir}/${destination_name}"

  info "Building ${build_scheme} -> ${destination_name}"
  bash "${BUILD_SCRIPT}" "${build_scheme}" "$@"

  if [[ ! -d "${source_path}" ]]; then
    error "XCFramework not found: ${source_path}"
  fi

  rm -rf "${destination_path}"
  cp -R "${source_path}" "${destination_path}"
  rm -rf "${BUILD_DIR:?}/${source_name}"
}

validate_package_dir() {
  local package_dir="$1"
  shift

  if [[ ! -d "${package_dir}" ]]; then
    error "Package directory not found: ${package_dir}"
  fi

  local xcframework_name
  for xcframework_name in "$@"; do
    local xcframework_path="${package_dir}/${xcframework_name}"
    if [[ ! -d "${xcframework_path}" ]]; then
      error "Expected XCFramework not found: ${xcframework_path}"
    fi

    if [[ ! -f "${xcframework_path}/Info.plist" ]]; then
      error "Invalid XCFramework, Info.plist not found: ${xcframework_path}"
    fi
  done

  info "Validated package directory: ${package_dir}"
}

validate_zip() {
  if [[ ! -s "${SDK_ZIP}" ]]; then
    error "Zip file not found or empty: ${SDK_ZIP}"
  fi

  if ! zipinfo -1 "${SDK_ZIP}" > /dev/null 2>&1; then
    error "Invalid zip file: ${SDK_ZIP}"
  fi

  info "Validated zip: ${SDK_ZIP}"
}

build_dynamic_package() {
  build_and_copy "FTMobileSDK-dynamic" \
    "FTMobileSDK-Dynamic" \
    "${DYNAMIC_DIR}" \
    "FTMobileSDK-Dynamic.xcframework"

  build_and_copy "FTSessionReplay-dynamic" \
    "FTSessionReplay-Dynamic" \
    "${DYNAMIC_DIR}" \
    "FTSessionReplay-Dynamic.xcframework"

  build_and_copy "FTMobileSDK-dynamic" \
    "FTMobileSDK-Dynamic-DisableSwizzlingResource" \
    "${DYNAMIC_DIR}" \
    "FTMobileSDK-Dynamic-DisableSwizzlingResource.xcframework" \
    --disable-swizzling-resource

  validate_package_dir "${DYNAMIC_DIR}" \
    "FTMobileSDK-Dynamic.xcframework" \
    "FTSessionReplay-Dynamic.xcframework" \
    "FTMobileSDK-Dynamic-DisableSwizzlingResource.xcframework"
}

build_static_package() {
  build_and_copy "FTMobileSDK" \
    "FTMobileSDK" \
    "${STATIC_DIR}" \
    "FTMobileSDK.xcframework"

  build_and_copy "FTSessionReplay" \
    "FTSessionReplay" \
    "${STATIC_DIR}" \
    "FTSessionReplay.xcframework"

  build_and_copy "FTMobileExtension" \
    "FTMobileExtension" \
    "${STATIC_DIR}" \
    "FTMobileExtension.xcframework"

  build_and_copy "FTMobileExtension" \
    "FTMobileExtension-DisableSwizzlingResource" \
    "${STATIC_DIR}" \
    "FTMobileExtension-DisableSwizzlingResource.xcframework" \
    --disable-swizzling-resource

  build_and_copy "FTMobileSDK" \
    "FTMobileSDK-DisableSwizzlingResource" \
    "${STATIC_DIR}" \
    "FTMobileSDK-DisableSwizzlingResource.xcframework" \
    --disable-swizzling-resource

  validate_package_dir "${STATIC_DIR}" \
    "FTMobileSDK.xcframework" \
    "FTSessionReplay.xcframework" \
    "FTMobileExtension.xcframework" \
    "FTMobileExtension-DisableSwizzlingResource.xcframework" \
    "FTMobileSDK-DisableSwizzlingResource.xcframework"
}

create_sdk_zip() {
  info "Compressing SDK package -> ${SDK_ZIP}"
  (
    cd "${STAGING_DIR}"
    zip -r -q "${SDK_ZIP}" "SDK-Static" "SDK-Dynamic"
  )
  validate_zip
}

main() {
  if [[ $# -gt 0 ]]; then
    case "$1" in
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        show_help
        error "Invalid argument: $1"
        ;;
    esac
  fi

  trap cleanup_temp_files EXIT

  check_env
  prepare_output
  build_static_package
  build_dynamic_package
  create_sdk_zip

  info "SDK zip: ${SDK_ZIP}"
}

main "$@"
