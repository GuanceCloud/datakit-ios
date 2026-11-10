# Generate hostless iOS/macOS Replay tests against this checkout's real SDK products.
require 'xcodeproj'
require 'fileutils'
root = File.expand_path('../..', __dir__)
output = ARGV.fetch(0, '/tmp/FTReplayCurrentContext')
platform = ARGV.fetch(1, 'ios').to_sym
FileUtils.mkdir_p(output)
project = Xcodeproj::Project.new(File.join(output, 'FTReplayCurrentContext.xcodeproj'))
target = project.new_target(:unit_test_bundle, 'FTReplayCurrentContext', platform, platform == :ios ? '15.0' : '12.0')
package = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
package.relative_path = root
project.root_object.package_references << package
['GuanceSDK', 'GuanceSessionReplay'].each do |name|
  product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  product.package = package
  product.product_name = name
  target.package_product_dependencies << product
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  target.frameworks_build_phase.files << build_file
  build_file.product_ref = product
end
['FTRecordingCoordinatorTests.m', 'FTReplayCurrentContextTests.m'].each do |name|
  file = project.main_group.new_file(File.join(root, 'Examples/iOS/Tests/FTMobileSDKUnitTests/SessionReplay', name))
  target.source_build_phase.add_file_reference(file)
end
target.build_configurations.each do |config|
  config.build_settings['HEADER_SEARCH_PATHS'] = ["#{root}/Sources/**"]
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.guance.tests.replay-current-context'
  config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
  config.build_settings['CLANG_ENABLE_OBJC_ARC'] = 'YES'
  config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.add_test_target(target)
scheme.save_as(project.path, 'FTReplayCurrentContext', true)
puts project.path
