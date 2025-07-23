# sh doccCoverage.sh all  Get documentation coverage for all files
# sh doccCoverage.sh      Get documentation coverage for public files
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
           echo "Already a Public file"
       else
           #brew install gnu-sed
           sed -i "" "$lineNum s/\}\;/settings = \{ATTRIBUTES = \(Public, \)\; \}\; \}\;/" $project_path
       fi
    fi
  fi
done
}

doccCoverage(){
echo '----- Cleaning in progress -----'
xcodebuild clean -quiet || exit
echo 'Cleaning completed -->>> build'
xcodebuild -target FTMobileSDK DOCC_EXTRACT_SWIFT_INFO_FOR_OBJC_SYMBOLS=NO -quiet || exit
echo 'build completion -->>> docc'
xcrun docc convert FTMobileSDK/FTMobileSDKDocs.docc \
--fallback-display-name FTMobileSDK \
--fallback-bundle-identifier com.cloudcare.ft.mobile.sdk.FTMobileSDK \
--fallback-bundle-version 1.0 \
--additional-symbol-graph-dir ./build/FTMobileSDK.build/Release-iphoneos/FTMobileSDK.build/symbol-graph \
--experimental-documentation-coverage \
--level detailed
}

# If "all", get documentation coverage for all files
FT_ALL_FILE_COVERAGE="$1"
echo "----- Start -----"

if [[ "$FT_ALL_FILE_COVERAGE" == "all" ]]; then
echo "-----changeFileAttributeToPublic Start-----"
changeFileAttributeToPublic
echo "-----changeFileAttributeToPublic End-----"
fi

# Remove the impact of old project
rm -rf App.xcodeproj
rm -rf App.xcworkspace

echo "-----Coverage Start-----"
doccCoverage
echo "-----Coverage End-----"

if [[ "$FT_ALL_FILE_COVERAGE" == "all" ]]; then
git checkout -- $project_path
echo "----- End -----"
fi
