#!/bin/bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
PODSPEC="${SCRIPT_DIR}/FTMobileSDK.podspec"
FRAMEWORK_SCRIPT="${SCRIPT_DIR}/BuildSDKPackages.sh"
SPM_VALIDATION_DIR="${BUILD_DIR}/SwiftPackageValidation"
SPM_DERIVED_DATA="${BUILD_DIR}/SwiftPackageDerivedData"
SPM_HOME="${BUILD_DIR}/SwiftPackageHome"
SPM_MODULE_CACHE="${BUILD_DIR}/SwiftPackageModuleCache"
SPM_DESTINATION="generic/platform=iOS"
XCODEBUILD_OPTIONS="${XCODEBUILD_OPTIONS--quiet}"
SPM_SCHEMES=(
  "FTMobileSDK"
  "FTMobileExtension"
  "FTSDKCore"
  "FTSessionReplay"
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
  bash VerifyDistributionPackages.sh [options]

Checks:
  cocoapods   pod lib lint FTMobileSDK.podspec
  framework   BuildSDKPackages.sh, then validates build/SDK.zip
  spm         Swift Package manifest + iOS xcodebuild build for all products

Options:
  --only <list>            Comma-separated checks to run: cocoapods,framework,spm
  --skip <list>            Comma-separated checks to skip: cocoapods,framework,spm
  --fail-fast              Stop at the first failed check
  --podspec <path>         Podspec path. Default: FTMobileSDK.podspec
  --spm-destination <dest> xcodebuild destination. Default: generic/platform=iOS
  --help, -h               Show this help

Environment:
  POD_LINT_OPTIONS         Extra options for pod lib lint.
                           Default: --allow-warnings --verbose
  XCODEBUILD_OPTIONS       Extra options for Swift Package xcodebuild.
                           Default: -quiet

Examples:
  bash VerifyDistributionPackages.sh
  bash VerifyDistributionPackages.sh --only cocoapods,spm
  POD_LINT_OPTIONS="--allow-warnings --verbose --no-clean" bash VerifyDistributionPackages.sh --only cocoapods
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

validate_cocoapods() {
  require_command "pod" || return 1

  if [[ ! -f "${PODSPEC}" ]]; then
    error "Podspec not found: ${PODSPEC}"
    return 1
  fi

  local lint_options="${POD_LINT_OPTIONS:---allow-warnings --verbose}"
  info "Running pod lib lint with options: ${lint_options}"
  # shellcheck disable=SC2086
  pod lib lint "${PODSPEC}" ${lint_options}
}

validate_framework_package() {
  require_command "xcodebuild" || return 1
  require_command "zip" || return 1
  require_command "zipinfo" || return 1

  if [[ ! -f "${FRAMEWORK_SCRIPT}" ]]; then
    error "Framework packaging script not found: ${FRAMEWORK_SCRIPT}"
    return 1
  fi

  bash "${FRAMEWORK_SCRIPT}"

  local sdk_zip="${BUILD_DIR}/SDK.zip"
  if [[ ! -s "${sdk_zip}" ]]; then
    error "SDK zip was not generated: ${sdk_zip}"
    return 1
  fi

  zipinfo -1 "${sdk_zip}" > /dev/null
}

prepare_spm_validation_dir() {
  mkdir -p "${BUILD_DIR}"
  rm -rf "${SPM_VALIDATION_DIR}" "${SPM_DERIVED_DATA}" "${SPM_HOME}" "${SPM_MODULE_CACHE}"
  mkdir -p "${SPM_VALIDATION_DIR}" "${SPM_HOME}" "${SPM_MODULE_CACHE}"

  cp "${SCRIPT_DIR}/Package.swift" "${SPM_VALIDATION_DIR}/Package.swift"
  ln -s "${SCRIPT_DIR}/FTMobileSDK" "${SPM_VALIDATION_DIR}/FTMobileSDK"
}

validate_swift_package() {
  require_command "swift" || return 1
  require_command "xcodebuild" || return 1

  if [[ ! -f "${SCRIPT_DIR}/Package.swift" ]]; then
    error "Package.swift not found: ${SCRIPT_DIR}/Package.swift"
    return 1
  fi

  prepare_spm_validation_dir

  (
    set -e
    cd "${SPM_VALIDATION_DIR}" || exit 1
    HOME="${SPM_HOME}" \
      CLANG_MODULE_CACHE_PATH="${SPM_MODULE_CACHE}" \
      swift package describe > /dev/null

    local scheme
    for scheme in "${SPM_SCHEMES[@]}"; do
      info "Building Swift Package scheme: ${scheme}"
      # shellcheck disable=SC2086
      HOME="${SPM_HOME}" \
        CLANG_MODULE_CACHE_PATH="${SPM_MODULE_CACHE}" \
        xcodebuild build \
        ${XCODEBUILD_OPTIONS} \
        -scheme "${scheme}" \
        -destination "${SPM_DESTINATION}" \
        -derivedDataPath "${SPM_DERIVED_DATA}" \
        CLANG_MODULE_CACHE_PATH="${SPM_MODULE_CACHE}" \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO
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
