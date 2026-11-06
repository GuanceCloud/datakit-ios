#  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http:#www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

# App-hosted regression: fixtures must live in the App image for the default SDK scan.
require 'xcodeproj'
require 'fileutils'
root = File.expand_path('../..', __dir__)
output = ARGV.fetch(0, '/tmp/FTSharedParserProbe')
sdk_root = File.expand_path(ARGV.fetch(1, root))
debug_log = ARGV.fetch(2, '0')
FileUtils.mkdir_p(output)
project = Xcodeproj::Project.new(File.join(output, 'FTSharedParserProbe.xcodeproj'))
app = project.new_target(:application, 'FTParserProbeApp', :ios, '15.0')
tests = project.new_target(:unit_test_bundle, 'FTSharedParserTests', :ios, '15.0')
tests.add_dependency(app)
package = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
package.relative_path = sdk_root
project.root_object.package_references << package
product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
product.package = package
product.product_name = 'GuanceSDK'
app.package_product_dependencies << product
build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
app.frameworks_build_phase.files << build_file
build_file.product_ref = product
%w[FTParserProbeApp.m FTSharedParserFixture.m].each do |name|
  app.source_build_phase.add_file_reference(project.main_group.new_file(File.join(root, 'Tests/AutoTrack/ParserProbe', name)))
end
tests.source_build_phase.add_file_reference(project.main_group.new_file(File.join(root, 'Tests/AutoTrack/ParserProbe/FTSharedParserIntegrationTests.m')))
[app, tests].each do |target|
  target.build_configurations.each do |config|
    config.build_settings['HEADER_SEARCH_PATHS'] = ["#{sdk_root}/Sources/**"]
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "com.guance.tests.#{target.name}"
    config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
    config.build_settings['CLANG_ENABLE_OBJC_ARC'] = 'YES'
    config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    config.build_settings['ENABLE_TESTABILITY'] = 'YES'
    config.build_settings['GCC_SYMBOLS_PRIVATE_EXTERN'] = 'NO'
    config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] = ['$(inherited)', "FT_PROBE_DEBUG_LOG=#{debug_log}"]
  end
end
app.build_configurations.each do |config|
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['INFOPLIST_FILE'] = File.join(output, 'AppInfo.plist')
  config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'YES'
end
Xcodeproj::Plist.write_to_path({
  'CFBundleExecutable' => '$(EXECUTABLE_NAME)',
  'CFBundleIdentifier' => '$(PRODUCT_BUNDLE_IDENTIFIER)',
  'CFBundleName' => '$(PRODUCT_NAME)',
  'CFBundlePackageType' => 'APPL',
  'CFBundleVersion' => '1',
  'CFBundleShortVersionString' => '1.0',
  'NSPrincipalClass' => 'UIApplication',
  'UILaunchScreen' => {},
  'UIApplicationSceneManifest' => {
    'UIApplicationSupportsMultipleScenes' => false,
    'UISceneConfigurations' => {
      'UIWindowSceneSessionRoleApplication' => [{
        'UISceneConfigurationName' => 'ParserProbe',
        'UISceneDelegateClassName' => 'FTParserProbeSceneDelegate'
      }]
    }
  }
}, File.join(output, 'AppInfo.plist'))
tests.build_configurations.each do |config|
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/FTParserProbeApp.app/FTParserProbeApp'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  config.build_settings['INFOPLIST_KEY_NSPrincipalClass'] = 'FTSharedParserIntegrationTests'
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_build_target(tests)
scheme.add_test_target(tests)
scheme.set_launch_target(app)
scheme.save_as(project.path, 'FTSharedParserProbe', true)
puts project.path
