#!/bin/bash

if [ -z "${BASH_VERSION:-}" ] || [ -n "${POSIXLY_CORRECT:-}" ]; then
  exec /bin/bash "$0" "$@"
fi

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

info() {
  echo "[INFO] $1"
}

error() {
  echo "[ERROR] $1" >&2
}

show_help() {
  cat <<'EOF'
Usage:
  bash scripts/check-license-headers.sh

Checks self-owned .h, .m, .mm, and .swift files under Sources/ and Examples/
for the Guance copyright header and Apache License 2.0 boilerplate.
EOF
}

is_supported_file() {
  case "$1" in
    Sources/SessionReplay/*.h|Sources/SessionReplay/*.m|Sources/SessionReplay/*.mm|Sources/SessionReplay/*.swift|Sources/SessionReplay/**/*.h|Sources/SessionReplay/**/*.m|Sources/SessionReplay/**/*.mm|Sources/SessionReplay/**/*.swift)
      return 0
      ;;
    Sources/*.h|Sources/*.m|Sources/*.mm|Sources/*.swift|Sources/**/*.h|Sources/**/*.m|Sources/**/*.mm|Sources/**/*.swift)
      return 0
      ;;
    Examples/*.h|Examples/*.m|Examples/*.mm|Examples/*.swift|Examples/**/*.h|Examples/**/*.m|Examples/**/*.mm|Examples/**/*.swift)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_skipped_path() {
  case "$1" in
    Sources/Core/DataManager/Storage/fmdb/*)
      return 0
      ;;
    Sources/Core/FTRUM/FTCrash/Recording/*|Sources/Core/FTRUM/FTCrash/RecordingCore/*)
      return 0
      ;;
    Sources/Core/FTRUM/include/FTCrashMonitorType.h)
      return 0
      ;;
    */Generated/*|*/generated/*|*.generated.swift|*.pb.swift|*.pbobjc.h|*.pbobjc.m)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

has_third_party_license() {
  sed -n '1,80p' "$1" | grep -Eq 'Copyright \(c\)|Permission is hereby granted|Karl Stenerud|Apple Inc\.|FMDB|Copyright 2019-Present Datadog|software derived from software developed at Datadog'
}

list_files() {
  git -C "${REPO_ROOT}" ls-files --cached --others --exclude-standard -- Sources Examples | while IFS= read -r file; do
    if [[ -L "${REPO_ROOT}/${file}" ]]; then
      continue
    fi

    if is_supported_file "${file}" && ! is_skipped_path "${file}" && ! has_third_party_license "${REPO_ROOT}/${file}"; then
      printf '%s\n' "${file}"
    fi
  done
}

has_complete_header() {
  perl -0ne 'exit(m{^//  Copyright [0-9]{4} Shanghai Guance Information Technology Co\., Ltd\.\n//\n//  Licensed under the Apache License, Version 2\.0 \(the "License"\);\n//  you may not use this file except in compliance with the License\.\n//  You may obtain a copy of the License at\n//\n//      http://www\.apache\.org/licenses/LICENSE-2\.0\n//\n//  Unless required by applicable law or agreed to in writing, software\n//  distributed under the License is distributed on an "AS IS" BASIS,\n//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied\.\n//  See the License for the specific language governing permissions and\n//  limitations under the License\.\n//}m ? 0 : 1)' "$1"
}

has_guance_copyright() {
  grep -Eq '^//  Copyright [0-9]{4} Shanghai Guance Information Technology Co\., Ltd\.$' "$1"
}

has_legacy_header_text() {
  sed -n '1,40p' "$1" | grep -Eq 'Copyright ©|Copyright [0-9]{3,4} (DataFlux-cn|GuanceCloud|hll)|All rights reserved\.'
}

check_file() {
  local rel_path="$1"
  local abs_path="${REPO_ROOT}/${rel_path}"
  local failed=0

  if has_legacy_header_text "${abs_path}"; then
    error "${rel_path}: contains legacy or incompatible copyright header"
    failed=1
  fi

  if ! has_guance_copyright "${abs_path}"; then
    error "${rel_path}: missing Guance copyright header"
    failed=1
  fi

  if ! has_complete_header "${abs_path}"; then
    error "${rel_path}: missing or malformed Apache License 2.0 header"
    failed=1
  fi

  return "${failed}"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  show_help
  exit 0
fi

checked=0
failed=0

while IFS= read -r file; do
  checked=$((checked + 1))
  if ! check_file "${file}"; then
    failed=1
  fi
done < <(list_files)

if [[ "${failed}" -ne 0 ]]; then
  error "License header check failed. Checked ${checked} files."
  exit 1
fi

info "License header check passed. Checked ${checked} files."
