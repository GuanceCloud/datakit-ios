#FT_PUSH_TAG="refs/tags/1.0.2-alpha.8"

VERSION=$(echo "$FT_PUSH_TAG" | sed -e 's/.*\///g' | sed -e 's/~.*//g' )
REPO_URL=git@github.com:GuanceCloud/datakit-ios.git

if git config remote.github.url; then
    git config remote.github.url $REPO_URL
else
    git remote add github $REPO_URL
fi

git push github $VERSION

if [[ $? -eq 0 ]];then

  sh UpdateSDKVersion.sh "$VERSION"

  pod trunk push FTMobileSDK.podspec --verbose --allow-warnings

else
  exit  1
fi


