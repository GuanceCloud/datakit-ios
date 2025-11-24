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

# Fix the issue of not finding static library libarclite_iphonesimulator.a/libarclite_iphoneos.a
post_install do |installer|
  installer.generated_projects.each do |project|
   project.targets.each do |target|
       target.build_configurations.each do |config|
           config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '11.0'
        end
   end
 end
  installer.pods_project.targets.each do |target|
    # Assuming your .xcconfig file is located in the Pods project directory, and the filename is 
    # Pods-TargetName.debug.xcconfig
    # You need to modify this path according to your project structure
    xcconfig_path = "Pods/Target Support Files/Pods-FTMobileSDKUnitTests/Pods-FTMobileSDKUnitTests.debug.xcconfig"
    # Check if the file exists
    if File.exist?(xcconfig_path)
      # Read file content
      xcconfig_content = File.read(xcconfig_path)
      # Use regular expression to replace -ObjC in OTHER_LDFLAGS
      new_xcconfig_content = xcconfig_content.gsub(/(OTHER_LDFLAGS\s*=\s*)(.*?)(-ObjC|\s-ObjC\s*)(.*?)/, "\\1\\2\\4")
      # Write back to file
      File.write(xcconfig_path, new_xcconfig_content)
      puts "Updated OTHER_LDFLAGS in #{xcconfig_path}"
    else
      puts "File #{xcconfig_path} does not exist."
    end
  end
end

