# sh doccCoverage.sh all  获取全部文档覆盖率
# sh doccCoverage.sh      获取 public 文件 文档覆盖率
project_path='FTMobileSDK.xcodeproj/project.pbxproj'
copyFile="test.pbxproj"

changeFileAttributeToPublic(){
states='init'
lineNum=0
cat -n $project_path | while read line
do
  lineNum=`expr $lineNum + 1`
  if [[ $line =~ 'Begin PBXBuildFile section */' ]]
  then
  states='start'
      echo $line
  elif [[ $line =~ 'End PBXBuildFile section */' ]]
  then
  states='end'
      echo $line
  elif [[ $states = 'start' ]]
  then
    if [[ $line =~ '.h in Headers */' ]];then
       if [[ $line =~ 'settings = {ATTRIBUTES = (Public,' ]];then
           echo "已经是 Public 文件"
       else
           #brew install gnu-sed
           sed -i "" "$lineNum s/\}\;/settings = \{ATTRIBUTES = \(Public, \)\; \}\; \}\;/" $project_path
       fi
    fi
  fi
done
}

doccCoverage(){
xcodebuild -target FTMobileSDK DOCC_EXTRACT_SWIFT_INFO_FOR_OBJC_SYMBOLS=NO

xcrun docc convert FTMobileSDK/FTMobileSDKDocs.docc \
--fallback-display-name FTMobileSDK \
--fallback-bundle-identifier com.cloudcare.ft.mobile.sdk.FTMobileSDK \
--fallback-bundle-version 1.0 \
--additional-symbol-graph-dir ./build/FTMobileSDK.build/Release-iphoneos/FTMobileSDK.build/symbol-graph \
--experimental-documentation-coverage \
--level detailed
}

# 若为 all 则获取所有文件的注释覆盖率
FT_ALL_FILE_COVERAGE="$1"
echo "----- Start -----"

if [[ "$FT_ALL_FILE_COVERAGE" == "all" ]]; then
echo "-----changeFileAttributeToPublic Start-----"
changeFileAttributeToPublic
echo "-----changeFileAttributeToPublic End-----"
fi

echo "-----Coverage Start-----"
doccCoverage
echo "-----Coverage End-----"

if [[ "$FT_ALL_FILE_COVERAGE" == "all" ]]; then
git checkout -- $project_path
echo "----- End -----"
fi
