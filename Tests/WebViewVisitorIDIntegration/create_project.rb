require 'xcodeproj'
root=ENV.fetch('WEBVISITOR_TEST_ROOT')
framework_path=ENV.fetch('WEBVISITOR_FRAMEWORK')
project=Xcodeproj::Project.new(root+'/Integration.xcodeproj')
target=project.new_target(:application,'WebVisitorIntegration',:ios,'15.0')
source=project.main_group.new_file('main.m');target.source_build_phase.add_file_reference(source)
support=project.main_group.new_file('Support.swift');target.source_build_phase.add_file_reference(support)
framework=project.frameworks_group.new_file(framework_path);target.frameworks_build_phase.add_file_reference(framework)
%w[WebKit UIKit Foundation Security SystemConfiguration CoreTelephony QuartzCore Network SwiftUI].each{|name|target.add_system_framework(name)}
target.build_configurations.each do |config|
 config.build_settings['PRODUCT_BUNDLE_IDENTIFIER']='com.guance.webvisitor.integration'
 config.build_settings['GENERATE_INFOPLIST_FILE']='NO'
 config.build_settings['INFOPLIST_FILE']=root+'/Info.plist'
 config.build_settings['SWIFT_VERSION']='5.0'
 config.build_settings['FRAMEWORK_SEARCH_PATHS']=['$(inherited)',File.dirname(framework_path)]
 config.build_settings['OTHER_LDFLAGS']=['$(inherited)','-ObjC','-lc++','-lsqlite3','-lz']
 config.build_settings['CLANG_ENABLE_MODULES']='YES'
 config.build_settings['CLANG_ENABLE_OBJC_ARC']='YES'
 config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']='15.0'
 config.build_settings['CODE_SIGNING_ALLOWED']='NO'
 config.build_settings['TARGETED_DEVICE_FAMILY']='1,2'
 config.build_settings['LD_RUNPATH_SEARCH_PATHS']=['$(inherited)','/usr/lib/swift','@executable_path/Frameworks']
end
project.save
