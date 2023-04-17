# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'
use_frameworks!
example_project_path = 'Examples/Examples'
workspace 'FTMobileSDK.xcworkspace'
project example_project_path

target 'App' do
  # Comment the next line if you don't want to use dynamic frameworks
  # Pods for SampleApp

end
target 'FTMobileSDKUnitTests' do
  # Comment the next line if you don't want to use dynamic frameworks
  project example_project_path
   pod 'OHHTTPStubs','8.0.0'
   pod 'KIF'
  # Pods for SampleApp

end

#解决找不到静态库 libarclite_iphonesimulator.a/libarclite_iphoneos.a 问题
post_install do |installer|
   installer.generated_projects.each do |project|
    project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '11.0'
         end
    end
  end
end
