#!/bin/sh
if [ -z "${BASH_VERSION:-}" ]; then
exec /bin/bash "$0" "$@"
fi

case ":${SHELLOPTS:-}:" in
*:posix:*)
exec /bin/bash "$0" "$@"
;;
esac

set -euo pipefail

#FT_PUSH_TAG="refs/tags/1.0.2-alpha.8"

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  shift
fi

if [[ -z "${FT_PUSH_TAG:-}" ]]; then
  echo "Error: FT_PUSH_TAG is required"
  exit 1
fi

VERSION=$(echo "$FT_PUSH_TAG" | sed -e 's/.*\///g' | sed -e 's/~.*//g' )
REPO_URL=git@github.com:GuanceCloud/datakit-ios.git

if [[ "$DRY_RUN" == "1" ]]; then
  echo "VERSION=$VERSION"
  echo "Would set remote github to $REPO_URL"
  echo "Would run: git push github $VERSION"
  echo "Would run: sh scripts/update-sdk-version.sh $VERSION"
  echo "Would run: pod trunk push GuanceSDK.podspec --verbose --allow-warnings"
  exit 0
fi

if git config remote.github.url; then
    git config remote.github.url "$REPO_URL"
else
    git remote add github "$REPO_URL"
fi

if git push github "$VERSION"; then

  sh scripts/update-sdk-version.sh "$VERSION"

  pod trunk push GuanceSDK.podspec --verbose --allow-warnings

else
  exit  1
fi
