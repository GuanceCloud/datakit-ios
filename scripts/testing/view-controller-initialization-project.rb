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

# Hostless tests link the real SDK without modifying the demo app project.
require 'xcodeproj'
require 'fileutils'
root = File.expand_path('../..', __dir__)
output = ARGV.fetch(0, '/tmp/FTViewControllerInitialization')
FileUtils.mkdir_p(output)
project = Xcodeproj::Project.new(File.join(output, 'FTViewControllerInitialization.xcodeproj'))
target = project.new_target(:unit_test_bundle, 'FTViewControllerInitialization', :ios, '15.0')
package = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
package.relative_path = root
project.root_object.package_references << package
product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
product.package = package
product.product_name = 'GuanceSDK'
target.package_product_dependencies << product
build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
target.frameworks_build_phase.files << build_file
build_file.product_ref = product
%w[FTViewControllerInitializationTests.m FTViewLoadingTimeConfigurationTests.m].each do |name|
  file = project.main_group.new_file(File.join(root, 'Tests/AutoTrack', name))
  target.source_build_phase.add_file_reference(file)
end
target.build_configurations.each do |config|
  config.build_settings['HEADER_SEARCH_PATHS'] = ["#{root}/Sources/**"]
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  # Otherwise NSBundle may select the first fixture as the bundle's principal class
  # and initialize it before XCTest begins, independently of SDK scanning.
  config.build_settings['INFOPLIST_KEY_NSPrincipalClass'] = 'FTViewControllerInitializationTests'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.guance.tests.view-controller-initialization'
  config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
  config.build_settings['CLANG_ENABLE_OBJC_ARC'] = 'YES'
  config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.add_test_target(target)
scheme.save_as(project.path, 'FTViewControllerInitialization', true)
puts project.path
