# 需要在目标机器上安装 oss util mac 版本，并且配置 akid 和 aksecret

#FT_PUSH_TAG="refs/tags/1.0.2-alpha.8"

replaceVersion(){

  PRODUCT_NAME=$1

  cd "$PRODUCT_NAME"

  sed  -i -e 's/SDK_VERSION.*/SDK_VERSION @"'$VERSION'"/g' "$PRODUCT_NAME"Version.h

  cd ..
}

git config remote.github.url >&- || git remote add github git@github.com:CloudCare/dataflux-sdk-ios.git
git push github -tags

#echo "version:$VERSION"
#echo "type:$FT_PROD_TYPE"

VERSION=$FT_PUSH_TAG

replaceVersion "FTAutoTrack"
replaceVersion "FTMobileAgent"

sed  -i -e 's/$JENKINS_DYNAMIC_VERSION/'"$VERSION"'/g' FTMobileSDK.podspec

pod trunk push FTMobileSDK.podspec --verbose --allow-warnings
