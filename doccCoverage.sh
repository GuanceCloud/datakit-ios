
cd FTMobileSDK
pwd
xcodebuild -target FTMobileAgent

xcrun docc convert FTMobileSDKDocs.docc \
--fallback-display-name FTMobileAgent \
--fallback-bundle-identifier com.cloudcare.ft.mobile.sdk.FTMobileAgent \
--fallback-bundle-version 1.0 \
--additional-symbol-graph-dir ./build/FTMobileSDK.build/Release-iphoneos/FTMobileAgent.build/symbol-graph \
--experimental-documentation-coverage \
--level detailed

