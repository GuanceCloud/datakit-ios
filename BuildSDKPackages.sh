#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_SCRIPT="${SCRIPT_DIR}/BuildFramework.sh"
BUILD_DIR="${SCRIPT_DIR}/build"
STAGING_DIR="${BUILD_DIR}/.SDKPackageStaging"
STATIC_DIR="${STAGING_DIR}/SDK-Static"
DYNAMIC_DIR="${STAGING_DIR}/SDK-Dynamic"
SDK_ZIP="${BUILD_DIR}/SDK.zip"

STATIC_XCFRAMEWORKS=(
  "FTMobileSDK.xcframework"
  "FTSessionReplay.xcframework"
  "FTMobileExtension.xcframework"
  "FTMobileExtension-DisableSwizzlingResource.xcframework"
  "FTMobileSDK-DisableSwizzlingResource.xcframework"
)

DYNAMIC_XCFRAMEWORKS=(
  "FTMobileSDK-Dynamic.xcframework"
  "FTSessionReplay-Dynamic.xcframework"
  "FTMobileSDK-Dynamic-DisableSwizzlingResource.xcframework"
)

PACKAGE_XCFRAMEWORKS=(
  "${STATIC_XCFRAMEWORKS[@]}"
  "${DYNAMIC_XCFRAMEWORKS[@]}"
)

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
  local xcframework_name
  for xcframework_name in "${PACKAGE_XCFRAMEWORKS[@]}"; do
    echo "  build/${xcframework_name}.zip"
  done
  echo ""
  echo "Each zip contains one XCFramework at the archive root."
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

remove_output_zips() {
  rm -f "${SDK_ZIP}"

  local xcframework_name
  for xcframework_name in "${PACKAGE_XCFRAMEWORKS[@]}"; do
    rm -f "${BUILD_DIR}/${xcframework_name}.zip"
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
  remove_output_zips
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
  local zip_path="$1"
  local xcframework_name="$2"

  if [[ ! -s "${zip_path}" ]]; then
    error "Zip file not found or empty: ${zip_path}"
  fi

  if ! zipinfo -1 "${zip_path}" "${xcframework_name}/Info.plist" > /dev/null 2>&1; then
    error "Invalid zip file or missing XCFramework Info.plist: ${zip_path}"
  fi

  info "Validated zip: ${zip_path}"
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
    "${DYNAMIC_XCFRAMEWORKS[@]}"
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
    "${STATIC_XCFRAMEWORKS[@]}"
}

create_xcframework_zip() {
  local package_dir="$1"
  local xcframework_name="$2"
  local zip_path="${BUILD_DIR}/${xcframework_name}.zip"

  info "Compressing ${xcframework_name} -> ${zip_path}"
  (
    cd "${package_dir}"
    zip -r -q "${zip_path}" "${xcframework_name}"
  )
  validate_zip "${zip_path}" "${xcframework_name}"
}

create_xcframework_zips() {
  local xcframework_name

  for xcframework_name in "${STATIC_XCFRAMEWORKS[@]}"; do
    create_xcframework_zip "${STATIC_DIR}" "${xcframework_name}"
  done

  for xcframework_name in "${DYNAMIC_XCFRAMEWORKS[@]}"; do
    create_xcframework_zip "${DYNAMIC_DIR}" "${xcframework_name}"
  done
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
  create_xcframework_zips

  info "SDK zip files:"
  local xcframework_name
  for xcframework_name in "${PACKAGE_XCFRAMEWORKS[@]}"; do
    info "  ${BUILD_DIR}/${xcframework_name}.zip"
  done
}

main "$@"
