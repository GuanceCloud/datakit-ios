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
# 拷贝原有的 project.pbxproj
copyProjectFile(){
# -f 参数判断 $file 是否存在
if [ ! -f "$copyFile" ]; then
 touch "$copyFile"
fi
cp  $project_path $copyFile
}
# 将 project.pbxproj 复原，删除拷贝文件
recoverProjectFile(){
cp  $copyFile $project_path
rm $copyFile
}

doccCoverage(){
xcodebuild -target FTMobileAgent DOCC_EXTRACT_SWIFT_INFO_FOR_OBJC_SYMBOLS=NO

xcrun docc convert FTMobileSDKDocs.docc \
--fallback-display-name FTMobileAgent \
--fallback-bundle-identifier com.cloudcare.ft.mobile.sdk.FTMobileAgent \
--fallback-bundle-version 1.0 \
--additional-symbol-graph-dir ./build/FTMobileSDK.build/Release-iphoneos/FTMobileAgent.build/symbol-graph \
--experimental-documentation-coverage \
--level detailed
}



cd FTMobileSDK
pwd
copyProjectFile
echo "-----changeFileAttributeToPublic Start-----"
changeFileAttributeToPublic
echo "-----changeFileAttributeToPublic End-----"

echo "-----Coverage Start-----"
doccCoverage
echo "-----Coverage End-----"

recoverProjectFile
