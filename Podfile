# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'
use_frameworks!
example_project_path = 'Examples/Examples'
workspace 'FTMobileSDK.xcworkspace'
project example_project_path

target 'FTMobileSDKUnitTests' do
  # Comment the next line if you don't want to use dynamic frameworks
  project example_project_path
   pod 'OHHTTPStubs','8.0.0'
   pod 'KIF','3.8.5'
   pod 'Firebase', '8.15.0'
   pod 'FirebasePerformance', '8.15.0'
  # Pods for SampleApp
end

target 'FTMobileSDKUnitTests-tvOS' do
  platform :tvos, '12.0'
  # Comment the next line if you don't want to use dynamic frameworks
   pod 'OHHTTPStubs','8.0.0'
   pod 'Firebase', '8.15.0'
   pod 'FirebasePerformance', '8.15.0'
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
  installer.pods_project.targets.each do |target|
    # 假设你的 .xcconfig 文件位于 Pods 项目目录下，并且文件名是 Pods-TargetName.debug.xcconfig
    # 你需要根据你的项目结构来修改这个路径
    xcconfig_path = "Pods/Target Support Files/Pods-FTMobileSDKUnitTests/Pods-FTMobileSDKUnitTests.debug.xcconfig"
    # 检查文件是否存在
    if File.exist?(xcconfig_path)
      # 读取文件内容
      xcconfig_content = File.read(xcconfig_path)
      # 使用正则表达式来替换 OTHER_LDFLAGS 中的 -ObjC
      new_xcconfig_content = xcconfig_content.gsub(/(OTHER_LDFLAGS\s*=\s*)(.*?)(-ObjC|\s-ObjC\s*)(.*?)/, "\\1\\2\\4")
      # 写回文件
      File.write(xcconfig_path, new_xcconfig_content)
      puts "Updated OTHER_LDFLAGS in #{xcconfig_path}"
    else
      puts "File #{xcconfig_path} does not exist."
    end
  end
end

