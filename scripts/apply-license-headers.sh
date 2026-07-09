#!/bin/bash

if [ -z "${BASH_VERSION:-}" ] || [ -n "${POSIXLY_CORRECT:-}" ]; then
  exec /bin/bash "$0" "$@"
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CURRENT_YEAR="$(date +%Y)"
CHECK_ONLY=0

info() {
  echo "[INFO] $1"
}

error() {
  echo "[ERROR] $1" >&2
}

show_help() {
  cat <<'EOF'
Usage:
  bash scripts/apply-license-headers.sh [--check|--dry-run]

Adds or normalizes the Guance copyright header and Apache License 2.0
boilerplate for self-owned source files under Sources/ and Examples/.

Options:
  --check, --dry-run  Report files that would change without modifying them.
  --help, -h          Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check|--dry-run)
      CHECK_ONLY=1
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    *)
      error "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
  shift
done

is_supported_file() {
  case "$1" in
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

extract_year() {
  local file="$1"
  local year
  year="$(perl -ne 'if (/Copyright\s+(?:©\s*)?([0-9]{3,4})\s+(?:Shanghai Guance Information Technology Co\., Ltd\.|DataFlux-cn\.?|GuanceCloud\.?|hll\.?)/) { print $1; exit }' "${file}")"

  if [[ -n "${year}" && "${year}" =~ ^[0-9]{4}$ ]]; then
    echo "${year}"
  else
    echo "${CURRENT_YEAR}"
  fi
}

has_complete_header() {
  perl -0ne 'exit(m{^//  Copyright [0-9]{4} Shanghai Guance Information Technology Co\., Ltd\.\n//\n//  Licensed under the Apache License, Version 2\.0 \(the "License"\);\n//  you may not use this file except in compliance with the License\.\n//  You may obtain a copy of the License at\n//\n//      http://www\.apache\.org/licenses/LICENSE-2\.0\n//\n//  Unless required by applicable law or agreed to in writing, software\n//  distributed under the License is distributed on an "AS IS" BASIS,\n//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied\.\n//  See the License for the specific language governing permissions and\n//  limitations under the License\.\n//}m ? 0 : 1)' "$1"
}

has_legacy_header_text() {
  sed -n '1,40p' "$1" | grep -Eq 'Copyright ©|Copyright [0-9]{3,4} (DataFlux-cn|GuanceCloud|hll)|All rights reserved\.'
}

rewrite_file_to_stdout() {
  local file="$1"
  local year="$2"

  perl -0we '
    use strict;
    use warnings;

    my ($file, $year) = @ARGV;
    open my $fh, "<", $file or die "Cannot read $file: $!";
    local $/;
    my $content = <$fh>;
    close $fh;

    sub header_for {
      my ($year) = @_;
      return join("\n",
        "//  Copyright $year Shanghai Guance Information Technology Co., Ltd.",
        "//",
        "//  Licensed under the Apache License, Version 2.0 (the \"License\");",
        "//  you may not use this file except in compliance with the License.",
        "//  You may obtain a copy of the License at",
        "//",
        "//      http://www.apache.org/licenses/LICENSE-2.0",
        "//",
        "//  Unless required by applicable law or agreed to in writing, software",
        "//  distributed under the License is distributed on an \"AS IS\" BASIS,",
        "//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.",
        "//  See the License for the specific language governing permissions and",
        "//  limitations under the License.",
        "//"
      ) . "\n";
    }

    sub strip_existing_header {
      my ($text) = @_;

      $text =~ s{^(//\s*Copyright\s+(?:©\s*)?[0-9]{3,4}\s+(?:Shanghai Guance Information Technology Co\., Ltd\.|DataFlux-cn\.?|GuanceCloud\.?|hll\.?)(?:\s+All rights reserved\.)?\s*\n)}{}mg;
      $text =~ s{^(//\s*\n(?=//\s*Licensed under the Apache License, Version 2\.0 \(the "License"\);))}{}mg;
      $text =~ s{
        ^//\s*Licensed\ under\ the\ Apache\ License,\ Version\ 2\.0\ \(the\ "License"\);\n
        ^//\s*you\ may\ not\ use\ this\ file\ except\ in\ compliance\ with\ the\ License\.\n
        ^//\s*You\ may\ obtain\ a\ copy\ of\ the\ License\ at\n
        ^//\s*\n
        ^//\s*http://www\.apache\.org/licenses/LICENSE-2\.0\n
        ^//\s*\n
        ^//\s*Unless\ required\ by\ applicable\ law\ or\ agreed\ to\ in\ writing,\ software\n
        ^//\s*distributed\ under\ the\ License\ is\ distributed\ on\ an\ "AS\ IS"\ BASIS,\n
        ^//\s*WITHOUT\ WARRANTIES\ OR\ CONDITIONS\ OF\ ANY\ KIND,\ either\ express\ or\ implied\.\n
        ^//\s*See\ the\ License\ for\ the\ specific\ language\ governing\ permissions\ and\n
        ^//\s*limitations\ under\ the\ License\.\n
        ^//\s*\n?
      }{}xmg;

      return $text;
    }

    $content = strip_existing_header($content);
    my $header = header_for($year);

    if ($content =~ s{\A((?://[^\n]*\n){0,20}//\s*Created by[^\n]*\n)(?://\s*\n)?}{$1 . $header . "\n"}e) {
      # Inserted into an existing Xcode-style header.
    } else {
      $content = $header . "\n" . $content;
    }

    print $content;
  ' "${file}" "${year}"
}

process_file() {
  local rel_path="$1"
  local abs_path="${REPO_ROOT}/${rel_path}"
  local year
  local tmp_file

  if ! has_legacy_header_text "${abs_path}" && has_complete_header "${abs_path}"; then
    return 1
  fi

  year="$(extract_year "${abs_path}")"
  tmp_file="$(mktemp)"

  rewrite_file_to_stdout "${abs_path}" "${year}" > "${tmp_file}"

  if cmp -s "${abs_path}" "${tmp_file}"; then
    rm -f "${tmp_file}"
    return 1
  fi

  if [[ "${CHECK_ONLY}" -eq 1 ]]; then
    echo "${rel_path}"
    rm -f "${tmp_file}"
    return 0
  fi

  cat "${tmp_file}" > "${abs_path}"
  rm -f "${tmp_file}"
  info "Updated ${rel_path}"
  return 0
}

changed=0
checked=0

while IFS= read -r file; do
  checked=$((checked + 1))
  if process_file "${file}"; then
    changed=$((changed + 1))
  fi
done < <(list_files)

if [[ "${CHECK_ONLY}" -eq 1 ]]; then
  if [[ "${changed}" -ne 0 ]]; then
    error "${changed} files would be updated. Checked ${checked} files."
    exit 1
  fi
  info "All license headers are already normalized. Checked ${checked} files."
  exit 0
fi

info "Updated ${changed} files. Checked ${checked} files."
