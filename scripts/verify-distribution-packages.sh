#!/bin/bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
PODSPEC="${REPO_ROOT}/GuanceSDK.podspec"
FRAMEWORK_SCRIPT="${SCRIPT_DIR}/build-sdk-packages.sh"
POD_CONSUMER_DIR="${REPO_ROOT}/Tests/CocoaPodsConsumer"
POD_CONSUMER_VALIDATION_DIR="${BUILD_DIR}/CocoaPodsConsumerValidation"
POD_CONSUMER_DERIVED_DATA="${BUILD_DIR}/CocoaPodsConsumerDerivedData"
FRAMEWORK_CONSUMER_DIR="${REPO_ROOT}/Tests/XCFrameworkConsumer"
FRAMEWORK_CONSUMER_VALIDATION_DIR="${BUILD_DIR}/XCFrameworkConsumerValidation"
FRAMEWORK_CONSUMER_DERIVED_DATA="${BUILD_DIR}/XCFrameworkConsumerDerivedData"
SPM_VALIDATION_DIR="${BUILD_DIR}/SwiftPackageValidation"
SPM_DERIVED_DATA="${BUILD_DIR}/SwiftPackageDerivedData"
SPM_MODULE_CACHE="${BUILD_DIR}/SwiftPackageModuleCache"
SPM_CONSUMER_DIR="${REPO_ROOT}/Tests/SwiftPMConsumer"
SPM_CONSUMER_DERIVED_DATA="${BUILD_DIR}/SwiftPackageConsumerDerivedData"
SPM_DESTINATION="${SPM_DESTINATION:-}"
SPM_PLATFORMS="${SPM_PLATFORMS:-ios,macos,tvos}"
XCODEBUILD_OPTIONS="${XCODEBUILD_OPTIONS--quiet}"
FRAMEWORK_ZIPS=(
  "GuanceSDK.xcframework.zip"
  "GuanceSessionReplay.xcframework.zip"
  "GuanceWidgetExtension.xcframework.zip"
  "GuanceWidgetExtension-DisableSwizzlingResource.xcframework.zip"
  "GuanceSDK-DisableSwizzlingResource.xcframework.zip"
  "GuanceSDK-Dynamic.xcframework.zip"
  "GuanceSessionReplay-Dynamic.xcframework.zip"
  "GuanceSDK-Dynamic-DisableSwizzlingResource.xcframework.zip"
)
SPM_SCHEMES=(
  "GuanceSDK"
  "GuanceWidgetExtension"
  "GuanceSessionReplay"
  "GuanceElectronWebView"
)
SPM_SCHEME_PLATFORMS=(
  "ios,macos,tvos"
  "ios"
  "ios,macos"
  "macos"
)
SPM_CONSUMER_SCHEMES=(
  "ObjCConsumer"
  "SessionReplayObjCConsumer"
  "SwiftConsumer"
  "SwiftUIConsumer"
)
SPM_BASE_CONSUMER_SCHEMES=(
  "ObjCConsumer"
  "SwiftConsumer"
)
POD_CONSUMER_SCHEMES=(
  "ObjCConsumer"
  "SwiftConsumer"
  "SwiftUIConsumer"
)
FRAMEWORK_CONSUMER_SCHEMES=(
  "ObjCConsumer"
  "SwiftConsumer"
  "SwiftUIConsumer"
)

RUN_COCOAPODS=1
RUN_FRAMEWORK=1
RUN_SPM=1
FAIL_FAST=0
FAILED_STEPS=()

info() {
  echo "[INFO] $1"
}

warn() {
  echo "[WARN] $1" >&2
}

error() {
  echo "[ERROR] $1" >&2
}

show_help() {
  cat <<'EOF'
Usage:
  bash scripts/verify-distribution-packages.sh [options]

Checks:
  cocoapods   pod lib lint + Objective-C/Swift/SwiftUI consumer links
  framework   builds XCFramework zips + Objective-C/Swift/SwiftUI consumer links
  spm         Swift Package manifest + product builds + Objective-C/Swift/SwiftUI consumer links

Options:
  --only <list>            Comma-separated checks to run: cocoapods,framework,spm
  --skip <list>            Comma-separated checks to skip: cocoapods,framework,spm
  --fail-fast              Stop at the first failed check
  --podspec <path>         Podspec path. Default: GuanceSDK.podspec
  --spm-platforms <list>   Comma-separated platforms to validate: ios,macos,tvos
                           Default: ios,macos,tvos
  --spm-destination <dest> xcodebuild destination override. When set, SPM builds
                           each selected product once with this destination.
  --help, -h               Show this help

Environment:
  POD_LINT_OPTIONS         Extra options for pod lib lint.
                           Default: --allow-warnings --verbose
  XCODEBUILD_OPTIONS       Extra options for Swift Package xcodebuild.
                           Default: -quiet
  RUBY_EXECUTABLE          Ruby with the xcodeproj gem for consumer project generation.
                           Default: ruby from PATH. Set GEM_HOME as needed.
  SPM_PLATFORMS            Same as --spm-platforms.
  SPM_DESTINATION          Same as --spm-destination.

Examples:
  bash scripts/verify-distribution-packages.sh
  bash scripts/verify-distribution-packages.sh --only cocoapods,spm
  POD_LINT_OPTIONS="--allow-warnings --verbose --no-clean" bash scripts/verify-distribution-packages.sh --only cocoapods
EOF
}

contains_item() {
  local list="$1"
  local item="$2"
  local old_ifs="$IFS"
  IFS=","
  set -- ${list}
  IFS="$old_ifs"

  local value
  for value in "$@"; do
    if [[ "${value}" == "${item}" ]]; then
      return 0
    fi
  done

  return 1
}

normalize_spm_platform() {
  local platform
  platform="$(echo "$1" | tr '[:upper:]' '[:lower:]')"

  case "${platform}" in
    ios|iphoneos)
      echo "ios"
      ;;
    macos|osx)
      echo "macos"
      ;;
    tvos|appletvos)
      echo "tvos"
      ;;
    *)
      error "Unsupported SPM platform: $1. Supported values: ios,macos,tvos"
      return 1
      ;;
  esac
}

normalize_spm_platform_list() {
  local list="$1"
  local old_ifs="$IFS"
  local normalized=()
  IFS=","
  set -- ${list}
  IFS="$old_ifs"

  local value
  local platform
  for value in "$@"; do
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    if [[ -z "${value}" ]]; then
      continue
    fi
    platform="$(normalize_spm_platform "${value}")" || return 1
    normalized+=("${platform}")
  done

  if [[ ${#normalized[@]} -eq 0 ]]; then
    error "SPM platform list is empty"
    return 1
  fi

  local old_ifs_join="$IFS"
  IFS=","
  echo "${normalized[*]}"
  IFS="$old_ifs_join"
}

spm_platform_destination() {
  case "$1" in
    ios)
      echo "generic/platform=iOS"
      ;;
    macos)
      echo "generic/platform=macOS"
      ;;
    tvos)
      echo "generic/platform=tvOS"
      ;;
    *)
      error "Unsupported SPM platform: $1"
      return 1
      ;;
  esac
}

spm_platform_display_name() {
  case "$1" in
    ios)
      echo "iOS"
      ;;
    macos)
      echo "macOS"
      ;;
    tvos)
      echo "tvOS"
      ;;
    *)
      echo "$1"
      ;;
  esac
}

spm_platform_selected() {
  local selected_platforms="$1"
  local platform="$2"

  contains_item "${selected_platforms}" "${platform}"
}

enable_only() {
  local list="$1"
  RUN_COCOAPODS=0
  RUN_FRAMEWORK=0
  RUN_SPM=0

  if contains_item "${list}" "cocoapods"; then
    RUN_COCOAPODS=1
  fi
  if contains_item "${list}" "framework"; then
    RUN_FRAMEWORK=1
  fi
  if contains_item "${list}" "spm"; then
    RUN_SPM=1
  fi
}

skip_checks() {
  local list="$1"

  if contains_item "${list}" "cocoapods"; then
    RUN_COCOAPODS=0
  fi
  if contains_item "${list}" "framework"; then
    RUN_FRAMEWORK=0
  fi
  if contains_item "${list}" "spm"; then
    RUN_SPM=0
  fi
}

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" > /dev/null 2>&1; then
    error "Required command not found: ${command_name}"
    return 1
  fi
}

run_step() {
  local step_name="$1"
  shift

  info "========== ${step_name} =========="
  "$@"
  local status=$?

  if [[ ${status} -eq 0 ]]; then
    info "${step_name} passed"
  else
    error "${step_name} failed with exit code ${status}"
    FAILED_STEPS+=("${step_name}")
    if [[ "${FAIL_FAST}" == "1" ]]; then
      exit "${status}"
    fi
  fi
}

resolve_xcodeproj_ruby() {
  local ruby_path="${RUBY_EXECUTABLE:-$(command -v ruby)}"
  if [[ -z "${ruby_path}" ]] || ! "${ruby_path}" -e 'require "xcodeproj"' > /dev/null 2>&1; then
    error "Ruby cannot load xcodeproj. Set RUBY_EXECUTABLE and GEM_HOME to the Ruby environment used by CocoaPods."
    return 1
  fi
  echo "${ruby_path}"
}

validate_cocoapods() {
  require_command "pod" || return 1
  require_command "xcodebuild" || return 1

  if [[ ! -f "${PODSPEC}" ]]; then
    error "Podspec not found: ${PODSPEC}"
    return 1
  fi

  local lint_options="${POD_LINT_OPTIONS:---allow-warnings --verbose}"
  local ruby_command
  ruby_command="$(resolve_xcodeproj_ruby)" || return 1
  info "Running pod lib lint with options: ${lint_options}"
  # shellcheck disable=SC2086
  pod lib lint "${PODSPEC}" ${lint_options} || return 1

  if [[ ! -f "${POD_CONSUMER_DIR}/Podfile" || ! -f "${POD_CONSUMER_DIR}/generate_project.rb" ]]; then
    error "CocoaPods consumer fixture not found: ${POD_CONSUMER_DIR}"
    return 1
  fi

  rm -rf "${POD_CONSUMER_VALIDATION_DIR}" "${POD_CONSUMER_DERIVED_DATA}"
  mkdir -p "${POD_CONSUMER_VALIDATION_DIR}"
  cp -R "${POD_CONSUMER_DIR}/." "${POD_CONSUMER_VALIDATION_DIR}"

  (
    cd "${POD_CONSUMER_VALIDATION_DIR}" || exit 1
    "${ruby_command}" generate_project.rb || exit 1
    pod install --no-repo-update || exit 1

    local scheme
    for scheme in "${POD_CONSUMER_SCHEMES[@]}"; do
      info "Building CocoaPods consumer: ${scheme} (iOS Simulator)"
      # shellcheck disable=SC2086
      xcodebuild build \
        ${XCODEBUILD_OPTIONS} \
        -workspace "${POD_CONSUMER_VALIDATION_DIR}/Consumer.xcworkspace" \
        -scheme "${scheme}" \
        -destination "generic/platform=iOS Simulator" \
        -derivedDataPath "${POD_CONSUMER_DERIVED_DATA}" \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO || exit 1
    done
  )
}

validate_xcframework_consumers() {
  local linkage="$1"
  local zip_name="$2"
  local extracted_name="$3"
  local validation_dir="${FRAMEWORK_CONSUMER_VALIDATION_DIR}/${linkage}"
  local derived_data="${FRAMEWORK_CONSUMER_DERIVED_DATA}/${linkage}"
  local zip_path="${BUILD_DIR}/${zip_name}"
  local ruby_command
  ruby_command="$(resolve_xcodeproj_ruby)" || return 1

  if [[ ! -f "${FRAMEWORK_CONSUMER_DIR}/generate_project.rb" ]]; then
    error "XCFramework consumer fixture not found: ${FRAMEWORK_CONSUMER_DIR}"
    return 1
  fi

  rm -rf "${validation_dir}" "${derived_data}"
  mkdir -p "${validation_dir}/Artifacts"
  cp -R "${FRAMEWORK_CONSUMER_DIR}/." "${validation_dir}"
  unzip -q "${zip_path}" -d "${validation_dir}/Artifacts" || return 1

  if [[ "${extracted_name}" != "GuanceSDK.xcframework" ]]; then
    mv \
      "${validation_dir}/Artifacts/${extracted_name}" \
      "${validation_dir}/Artifacts/GuanceSDK.xcframework" || return 1
  fi

  (
    cd "${validation_dir}" || exit 1
    GUANCE_XCFRAMEWORK_LINKAGE="${linkage}" \
      "${ruby_command}" generate_project.rb || exit 1
  ) || return 1

  local scheme
  for scheme in "${FRAMEWORK_CONSUMER_SCHEMES[@]}"; do
    info "Building ${linkage} XCFramework consumer: ${scheme} (iOS Simulator)"
    # shellcheck disable=SC2086
    xcodebuild build \
      ${XCODEBUILD_OPTIONS} \
      -project "${validation_dir}/Consumer.xcodeproj" \
      -scheme "${scheme}" \
      -destination "generic/platform=iOS Simulator" \
      -derivedDataPath "${derived_data}" \
      CODE_SIGNING_ALLOWED=NO \
      CODE_SIGNING_REQUIRED=NO || return 1
  done
}

validate_framework_package() {
  require_command "xcodebuild" || return 1
  require_command "zip" || return 1
  require_command "zipinfo" || return 1
  require_command "unzip" || return 1
  require_command "plutil" || return 1
  require_command "grep" || return 1

  if [[ ! -f "${FRAMEWORK_SCRIPT}" ]]; then
    error "Framework packaging script not found: ${FRAMEWORK_SCRIPT}"
    return 1
  fi

  if ! bash "${FRAMEWORK_SCRIPT}"; then
    error "Framework packaging script failed: ${FRAMEWORK_SCRIPT}"
    return 1
  fi

  local zip_name
  for zip_name in "${FRAMEWORK_ZIPS[@]}"; do
    local zip_path="${BUILD_DIR}/${zip_name}"
    local xcframework_name="${zip_name%.zip}"

    if [[ ! -s "${zip_path}" ]]; then
      error "Framework zip was not generated: ${zip_path}"
      return 1
    fi

    zipinfo -1 "${zip_path}" "${xcframework_name}/Info.plist" > /dev/null || return 1

    case "${zip_name}" in
      GuanceSessionReplay.xcframework.zip|GuanceSessionReplay-Dynamic.xcframework.zip)
        if ! unzip -p "${zip_path}" "${xcframework_name}/Info.plist" \
          | plutil -p - \
          | grep -q '"SupportedPlatform" => "macos"'; then
          error "Session Replay XCFramework is missing a macOS slice: ${zip_path}"
          return 1
        fi
        ;;
    esac
  done

  validate_xcframework_consumers \
    "static" \
    "GuanceSDK.xcframework.zip" \
    "GuanceSDK.xcframework" || return 1
  validate_xcframework_consumers \
    "dynamic" \
    "GuanceSDK-Dynamic.xcframework.zip" \
    "GuanceSDK-Dynamic.xcframework" || return 1
}

prepare_spm_validation_dir() {
  mkdir -p "${BUILD_DIR}"
  rm -rf "${SPM_VALIDATION_DIR}" "${SPM_DERIVED_DATA}" "${SPM_CONSUMER_DERIVED_DATA}" "${SPM_MODULE_CACHE}"
  mkdir -p "${SPM_VALIDATION_DIR}" "${SPM_MODULE_CACHE}"

  cp "${REPO_ROOT}/Package.swift" "${SPM_VALIDATION_DIR}/Package.swift"
  ln -s "${REPO_ROOT}/Sources" "${SPM_VALIDATION_DIR}/Sources"
  mkdir -p "${SPM_VALIDATION_DIR}/Tests"
  ln -s "${REPO_ROOT}/Tests/FTLoggerTests" "${SPM_VALIDATION_DIR}/Tests/FTLoggerTests"
  ln -s "${REPO_ROOT}/Tests/GuanceElectronWebViewTests" "${SPM_VALIDATION_DIR}/Tests/GuanceElectronWebViewTests"
  ln -s "${REPO_ROOT}/Tests/GuanceElectronNativeTests" "${SPM_VALIDATION_DIR}/Tests/GuanceElectronNativeTests"
}

build_swift_package_scheme() {
  local scheme="$1"
  local destination="$2"
  local platform_name="$3"

  info "Building Swift Package scheme: ${scheme} (${platform_name}, ${destination})"
  # shellcheck disable=SC2086
  CLANG_MODULE_CACHE_PATH="${SPM_MODULE_CACHE}" \
    xcodebuild build \
    ${XCODEBUILD_OPTIONS} \
    -scheme "${scheme}" \
    -destination "${destination}" \
    -derivedDataPath "${SPM_DERIVED_DATA}" \
    CLANG_MODULE_CACHE_PATH="${SPM_MODULE_CACHE}" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO
}

build_swift_package_consumers() {
  local platform="$1"
  if [[ ! -f "${SPM_CONSUMER_DIR}/Package.swift" ]]; then
    error "Swift Package consumer fixture not found: ${SPM_CONSUMER_DIR}/Package.swift"
    return 1
  fi

  local destination
  local platform_name
  local schemes=()
  case "${platform}" in
    ios)
      destination="generic/platform=iOS Simulator"
      platform_name="iOS Simulator"
      schemes=("${SPM_CONSUMER_SCHEMES[@]}")
      ;;
    macos)
      destination="generic/platform=macOS"
      platform_name="macOS"
      schemes=("${SPM_BASE_CONSUMER_SCHEMES[@]}")
      ;;
    *)
      warn "Skipping Swift Package consumers on $(spm_platform_display_name "${platform}")"
      return 0
      ;;
  esac

  local scheme
  for scheme in "${schemes[@]}"; do
    info "Building Swift Package consumer: ${scheme} (${platform_name})"
    (
      cd "${SPM_CONSUMER_DIR}" || exit 1
      # shellcheck disable=SC2086
      CLANG_MODULE_CACHE_PATH="${SPM_MODULE_CACHE}" \
        xcodebuild build \
        ${XCODEBUILD_OPTIONS} \
        -scheme "${scheme}" \
        -destination "${destination}" \
        -derivedDataPath "${SPM_CONSUMER_DERIVED_DATA}" \
        CLANG_MODULE_CACHE_PATH="${SPM_MODULE_CACHE}" \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO
    ) || return 1
  done
}

validate_swift_package() {
  require_command "swift" || return 1
  require_command "xcodebuild" || return 1

  if [[ ! -f "${REPO_ROOT}/Package.swift" ]]; then
    error "Package.swift not found: ${REPO_ROOT}/Package.swift"
    return 1
  fi

  prepare_spm_validation_dir

  (
    set -e
    cd "${SPM_VALIDATION_DIR}" || exit 1
    CLANG_MODULE_CACHE_PATH="${SPM_MODULE_CACHE}" \
      swift package describe > /dev/null

    local selected_platforms
    selected_platforms="$(normalize_spm_platform_list "${SPM_PLATFORMS}")"

    local old_ifs="$IFS"
    IFS=","
    local selected_platform_array=(${selected_platforms})
    IFS="$old_ifs"

    local index
    local scheme
    local scheme_platforms
    local platform
    local destination
    local should_build_with_override

    for index in "${!SPM_SCHEMES[@]}"; do
      scheme="${SPM_SCHEMES[${index}]}"
      scheme_platforms="${SPM_SCHEME_PLATFORMS[${index}]}"

      if [[ -n "${SPM_DESTINATION}" ]]; then
        should_build_with_override=0
        for platform in "${selected_platform_array[@]}"; do
          if spm_platform_selected "${scheme_platforms}" "${platform}"; then
            should_build_with_override=1
            break
          fi
        done
        if [[ "${should_build_with_override}" == "1" ]]; then
          build_swift_package_scheme "${scheme}" "${SPM_DESTINATION}" "custom"
        else
          warn "Skipping Swift Package scheme ${scheme}; selected platforms (${selected_platforms}) do not match supported platforms (${scheme_platforms})"
        fi
        continue
      fi

      for platform in "${selected_platform_array[@]}"; do
        if ! spm_platform_selected "${scheme_platforms}" "${platform}"; then
          warn "Skipping Swift Package scheme ${scheme} on $(spm_platform_display_name "${platform}")"
          continue
        fi

        destination="$(spm_platform_destination "${platform}")"
        build_swift_package_scheme "${scheme}" "${destination}" "$(spm_platform_display_name "${platform}")"
      done
    done

    for platform in "${selected_platform_array[@]}"; do
      build_swift_package_consumers "${platform}"
    done
  )
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --only)
        if [[ $# -lt 2 ]]; then
          error "Missing value for --only"
          exit 1
        fi
        enable_only "$2"
        shift 2
        ;;
      --skip)
        if [[ $# -lt 2 ]]; then
          error "Missing value for --skip"
          exit 1
        fi
        skip_checks "$2"
        shift 2
        ;;
      --fail-fast)
        FAIL_FAST=1
        shift
        ;;
      --podspec)
        if [[ $# -lt 2 ]]; then
          error "Missing value for --podspec"
          exit 1
        fi
        PODSPEC="$2"
        shift 2
        ;;
      --spm-platforms)
        if [[ $# -lt 2 ]]; then
          error "Missing value for --spm-platforms"
          exit 1
        fi
        SPM_PLATFORMS="$2"
        shift 2
        ;;
      --spm-destination)
        if [[ $# -lt 2 ]]; then
          error "Missing value for --spm-destination"
          exit 1
        fi
        SPM_DESTINATION="$2"
        shift 2
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        error "Invalid argument: $1"
        show_help
        exit 1
        ;;
    esac
  done
}

print_summary() {
  echo ""
  info "========== Summary =========="

  if [[ ${#FAILED_STEPS[@]} -eq 0 ]]; then
    info "All selected distribution checks passed."
    return 0
  fi

  error "Failed checks:"
  local step
  for step in "${FAILED_STEPS[@]}"; do
    error "  - ${step}"
  done
  return 1
}

main() {
  parse_args "$@"

  if [[ "${RUN_COCOAPODS}" == "1" ]]; then
    run_step "CocoaPods package validation" validate_cocoapods
  else
    warn "Skipping CocoaPods package validation"
  fi

  if [[ "${RUN_FRAMEWORK}" == "1" ]]; then
    run_step "Framework package validation" validate_framework_package
  else
    warn "Skipping framework package validation"
  fi

  if [[ "${RUN_SPM}" == "1" ]]; then
    run_step "Swift Package validation" validate_swift_package
  else
    warn "Skipping Swift Package validation"
  fi

  print_summary
}

main "$@"
