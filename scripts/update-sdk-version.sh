#!/bin/sh
set -e

usage() {
  echo "Usage: sh scripts/update-sdk-version.sh <version|refs/tags/version>"
  echo "Example: sh scripts/update-sdk-version.sh 1.6.5-alpha.1"
}

VERSION_INPUT="${1:-${FT_PUSH_TAG:-}}"
if [ -z "$VERSION_INPUT" ]; then
  usage
  exit 1
fi

VERSION=$(printf '%s\n' "$VERSION_INPUT" | sed -e 's/.*\///g' -e 's/~.*//g')
INFO_PLIST_VERSION=$(printf '%s\n' "$VERSION" | sed -E 's/-(alpha|beta)\.[0-9]+$//')
SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd "$SCRIPT_DIR/.." && pwd)

cd "$REPO_ROOT"

PODSPEC="GuanceSDK.podspec"
VERSION_HEADER="Sources/Agent/Core/FTSDKVersion.h"
INFO_PLIST="Sources/Info.plist"

for file in "$PODSPEC" "$VERSION_HEADER" "$INFO_PLIST"; do
  if [ ! -f "$file" ]; then
    echo "Error: file not found: $file"
    exit 1
  fi
done

sed -i '' -E 's/^#define[[:space:]]+SDK_VERSION[[:space:]]+@"[^"]*"/#define SDK_VERSION  @"'"$VERSION"'"/' "$VERSION_HEADER"

sed -i '' -E '/^[[:space:]]*s[[:space:]]*\.[[:space:]]*version[[:space:]]*=/s/"[^"]*"/"'"$VERSION"'"/' "$PODSPEC"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $INFO_PLIST_VERSION" "$INFO_PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $INFO_PLIST_VERSION" "$INFO_PLIST"

echo "Updated SDK version:"
echo "  $PODSPEC: $VERSION"
echo "  $VERSION_HEADER: $VERSION"
echo "  $INFO_PLIST CFBundleShortVersionString: $INFO_PLIST_VERSION"
