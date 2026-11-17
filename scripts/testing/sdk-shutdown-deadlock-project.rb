# Copyright 2026 TRUEWATCH TECHNOLOGY INC PTE. LTD.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Generate only a temporary isolated App; do not edit production project files.
# No external gem is required. Output must not already exist.
require 'fileutils'
require 'json'
require 'cgi'

root = File.expand_path('../..', __dir__)
output = File.expand_path(ARGV.fetch(0))
abort 'Output already exists; choose a fresh evidence directory' if File.exist?(output)
manifest = File.read(File.join(root, 'Package.swift'))
product = manifest[/let package = Package\(\s*name:\s*"([^"]+)"/m, 1]
abort 'Cannot identify the existing main package product' unless product
FileUtils.mkdir_p(File.join(output, 'FTSDKShutdownDeadlockProbe.xcodeproj', 'xcshareddata', 'xcschemes'))

def quoted(value)
  JSON.generate(value)
end

objects = {}
serial = 0
add = lambda do |body|
  serial += 1
  key = format('%024X', serial)
  objects[key] = body
  key
end
source = add.call("isa = PBXFileReference; lastKnownFileType = sourcecode.c.objc; path = #{quoted(File.join(root, 'Tests/Lifecycle/FTSDKShutdownDeadlockProbe.m'))}; sourceTree = \"<absolute>\";")
app = add.call('isa = PBXFileReference; explicitFileType = wrapper.application; path = FTSDKShutdownDeadlockProbe.app; sourceTree = BUILT_PRODUCTS_DIR;')
source_build = add.call("isa = PBXBuildFile; fileRef = #{source};")
package = add.call("isa = XCLocalSwiftPackageReference; relativePath = #{quoted(root)};")
dependency = add.call("isa = XCSwiftPackageProductDependency; package = #{package}; productName = #{quoted(product)};")
sdk_build = add.call("isa = PBXBuildFile; productRef = #{dependency};")
framework_builds = %w[UIKit Foundation].map do |name|
  ref = add.call("isa = PBXFileReference; lastKnownFileType = wrapper.framework; path = System/Library/Frameworks/#{name}.framework; sourceTree = SDKROOT;")
  add.call("isa = PBXBuildFile; fileRef = #{ref};")
end
sources = add.call("isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (#{source_build},); runOnlyForDeploymentPostprocessing = 0;")
frameworks = add.call("isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (#{([sdk_build] + framework_builds).join(',')},); runOnlyForDeploymentPostprocessing = 0;")
products = add.call("isa = PBXGroup; children = (#{app},); name = Products; sourceTree = \"<group>\";")
group = add.call("isa = PBXGroup; children = (#{source},#{products},); sourceTree = \"<group>\";")
settings = {
  'SDKROOT' => 'iphoneos', 'IPHONEOS_DEPLOYMENT_TARGET' => '15.0',
  'CLANG_ENABLE_OBJC_ARC' => 'YES', 'CLANG_ENABLE_MODULES' => 'YES',
  'ONLY_ACTIVE_ARCH' => 'YES',
  'GCC_OPTIMIZATION_LEVEL' => '0', 'DEBUG_INFORMATION_FORMAT' => 'dwarf-with-dsym',
  'PRODUCT_NAME' => 'FTSDKShutdownDeadlockProbe',
  'PRODUCT_BUNDLE_IDENTIFIER' => 'com.truewatch.audit.lc001',
  'INFOPLIST_FILE' => File.join(output, 'Info.plist'),
  'CODE_SIGN_STYLE' => 'Manual', 'CODE_SIGN_IDENTITY' => '-',
  'CODE_SIGN_ENTITLEMENTS' => File.join(output, 'Probe.entitlements'),
  'TARGETED_DEVICE_FAMILY' => '1,2', 'ENABLE_USER_SCRIPT_SANDBOXING' => 'YES',
  'HEADER_SEARCH_PATHS' => ["#{root}/Sources/**"], 'OTHER_LDFLAGS' => ['-ObjC']
}
formatted_settings = settings.map do |key, value|
  rendered = value.is_a?(Array) ? "(#{value.map { |x| quoted(x) }.join(',')},)" : quoted(value)
  "#{key} = #{rendered};"
end.join("\n")
config = add.call("isa = XCBuildConfiguration; name = Debug; buildSettings = {#{formatted_settings}};")
configs = add.call("isa = XCConfigurationList; buildConfigurations = (#{config},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;")
target = add.call("isa = PBXNativeTarget; buildConfigurationList = #{configs}; buildPhases = (#{sources},#{frameworks},); buildRules = (); dependencies = (); name = FTSDKShutdownDeadlockProbe; packageProductDependencies = (#{dependency},); productName = FTSDKShutdownDeadlockProbe; productReference = #{app}; productType = \"com.apple.product-type.application\";")
project_config = add.call('isa = XCBuildConfiguration; name = Debug; buildSettings = {CLANG_ENABLE_MODULES = YES;};')
project_configs = add.call("isa = XCConfigurationList; buildConfigurations = (#{project_config},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;")
project = add.call("isa = PBXProject; attributes = {LastUpgradeCheck = 2700;}; buildConfigurationList = #{project_configs}; compatibilityVersion = \"Xcode 14.0\"; developmentRegion = en; knownRegions = (en,Base,); mainGroup = #{group}; productRefGroup = #{products}; packageReferences = (#{package},); projectDirPath = \"\"; projectRoot = \"\"; targets = (#{target},);")
File.write(File.join(output, 'FTSDKShutdownDeadlockProbe.xcodeproj', 'project.pbxproj'),
  "// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n" +
  objects.map { |key, value| "#{key} = {#{value}};" }.join("\n") + "\n}; rootObject = #{project};}\n")
File.write(File.join(output, 'Info.plist'), <<~PLIST)
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
  <key>CFBundleExecutable</key><string>$(EXECUTABLE_NAME)</string>
  <key>CFBundleName</key><string>$(PRODUCT_NAME)</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string><key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSRequiresIPhoneOS</key><true/><key>UILaunchScreen</key><dict/>
  <key>UIApplicationSceneManifest</key><dict><key>UIApplicationSupportsMultipleScenes</key><false/>
  <key>UISceneConfigurations</key><dict><key>UIWindowSceneSessionRoleApplication</key><array><dict>
  <key>UISceneConfigurationName</key><string>LC001</string>
  <key>UISceneDelegateClassName</key><string>FTLC001SceneDelegate</string>
  </dict></array></dict></dict></dict></plist>
PLIST
File.write(File.join(output, 'Probe.entitlements'), <<~PLIST)
  <?xml version="1.0" encoding="UTF-8"?>
  <plist version="1.0"><dict><key>get-task-allow</key><true/></dict></plist>
PLIST
File.write(File.join(output, 'FTSDKShutdownDeadlockProbe.xcodeproj', 'xcshareddata', 'xcschemes', 'FTSDKShutdownDeadlockProbe.xcscheme'), <<~XML)
  <?xml version="1.0" encoding="UTF-8"?>
  <Scheme LastUpgradeVersion="2700" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
  <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">
  <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="#{target}" BuildableName="FTSDKShutdownDeadlockProbe.app" BlueprintName="FTSDKShutdownDeadlockProbe" ReferencedContainer="container:FTSDKShutdownDeadlockProbe.xcodeproj"/>
  </BuildActionEntry></BuildActionEntries></BuildAction></Scheme>
XML
puts JSON.pretty_generate(root: root, product: product, project: File.join(output, 'FTSDKShutdownDeadlockProbe.xcodeproj'), scheme: 'FTSDKShutdownDeadlockProbe', bundle_id: 'com.truewatch.audit.lc001')
