# 需要在目标机器上安装 oss util mac 版本，并且配置 akid 和 aksecret

#FT_PUSH_TAG="refs/tags/1.0.2-alpha.8"

replaceVersion(){

  PRODUCT_NAME=$1

  cd "FTMobileSDK/$PRODUCT_NAME" || exit

  sed  -i '' 's/SDK_VERSION.*/SDK_VERSION @"'$VERSION'"/g' "$PRODUCT_NAME"Version.h

  cd ../..
}

git config remote.github.url >&- || git remote add github git@github.com:DataFlux-cn/datakit-ios.git
git push github --tags

if [[ $? -eq 0 ]];then
  #echo "version:$VERSION"
  #echo "type:$FT_PROD_TYPE"

  VERSION=$(echo "$FT_PUSH_TAG" | sed -e 's/.*\///g' | sed -e 's/~.*//g' )

  replaceVersion "FTAutoTrack"
  replaceVersion "FTMobileAgent"

  sed  -i '' 's/$JENKINS_DYNAMIC_VERSION/'"$VERSION"'/g' FTMobileSDK.podspec

  pod trunk push FTMobileSDK.podspec --verbose --allow-warnings
fi




