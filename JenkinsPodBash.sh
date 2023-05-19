#FT_PUSH_TAG="refs/tags/1.0.2-alpha.8"

VERSION=$(echo "$FT_PUSH_TAG" | sed -e 's/.*\///g' | sed -e 's/~.*//g' )

if git config remote.github.url; then git config remote.github.url git@github.com:GuanceCloud/datakit-ios.git; else git remote add github git@github.com:GuanceCloud/datakit-macos.git; fi
git push github $VERSION

if [[ $? -eq 0 ]];then

  sed  -i '' 's/SDK_VERSION.*/SDK_VERSION @"'$VERSION'"/g' FTMobileSDK/FTMobileAgent/Core/FTMobileAgentVersion.h

  sed  -i '' 's/$JENKINS_DYNAMIC_VERSION/'"$VERSION"'/g' FTMobileSDK.podspec

  pod trunk push FTMobileSDK.podspec --verbose --allow-warnings

else
  exit  1
fi




