#FT_PUSH_TAG="refs/tags/1.0.2-alpha.8"

VERSION=$(echo "$FT_PUSH_TAG" | sed -e 's/.*\///g' | sed -e 's/~.*//g' )

git config remote.github.url >&- || git remote add github git@github.com:DataFlux-cn/datakit-ios.git
git push github $VERSION

if [[ $? -eq 0 ]];then

  sed  -i '' 's/SDK_VERSION.*/SDK_VERSION @"'$VERSION'"/g' FTMobileSDK/FTMobileAgent/Core/FTMobileAgentVersion.h

  sed  -i '' 's/$JENKINS_DYNAMIC_VERSION/'"$VERSION"'/g' FTMobileSDK.podspec

  pod trunk push FTMobileSDK.podspec --verbose --allow-warnings

else
  exit  1
fi




