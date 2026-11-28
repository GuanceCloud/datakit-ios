require 'fileutils'
require 'xcodeproj'

fixture_dir = File.expand_path(__dir__)
project_path = File.join(fixture_dir, 'Consumer.xcodeproj')
FileUtils.rm_rf(project_path)
linkage = ENV.fetch('GUANCE_XCFRAMEWORK_LINKAGE', 'static')

unless %w[static dynamic].include?(linkage)
  abort "Unsupported GUANCE_XCFRAMEWORK_LINKAGE: #{linkage}"
end

project = Xcodeproj::Project.new(project_path)
sources_group = project.main_group.new_group('Sources', 'Sources')
framework_reference = project.frameworks_group.new_file('Artifacts/GuanceSDK.xcframework')

targets = {
  'ObjCConsumer' => 'ObjCConsumer/main.m',
  'SwiftConsumer' => 'SwiftConsumer/App.swift',
  'SwiftUIConsumer' => 'SwiftUIConsumer/App.swift'
}

targets.each do |name, relative_source|
  target = project.new_target(:application, name, :ios, '15.0')
  source_reference = sources_group.new_file(relative_source)
  target.add_file_references([source_reference])
  target.frameworks_build_phase.add_file_reference(framework_reference)

  if linkage == 'dynamic'
    embed_phase = target.new_copy_files_build_phase('Embed Frameworks')
    embed_phase.dst_subfolder_spec = '10'
    embed_file = embed_phase.add_file_reference(framework_reference, true)
    embed_file.settings = { 'ATTRIBUTES' => %w[CodeSignOnCopy RemoveHeadersOnCopy] }
  end

  target.build_configurations.each do |configuration|
    configuration.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    configuration.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
    configuration.build_settings['CURRENT_PROJECT_VERSION'] = '1'
    configuration.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    configuration.build_settings['MARKETING_VERSION'] = '1.0'
    configuration.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "com.guance.xcframework-consumer.#{name.downcase}"
    configuration.build_settings['SWIFT_VERSION'] = '5.0' unless name == 'ObjCConsumer'

    # A pure Objective-C host does not invoke the Swift linker driver. The static
    # GuanceSDK framework already contains Swift and C++ objects, so the host must
    # expose the toolchain Swift compatibility libraries and link libc++.
    if linkage == 'static' && name == 'ObjCConsumer'
      configuration.build_settings['LIBRARY_SEARCH_PATHS'] = [
        '$(inherited)',
        '$(TOOLCHAIN_DIR)/usr/lib/swift/$(PLATFORM_NAME)'
      ]
      configuration.build_settings['OTHER_LDFLAGS'] = ['$(inherited)', '-lc++']
    end
  end

  scheme = Xcodeproj::XCScheme.new
  scheme.add_build_target(target)
  scheme.set_launch_target(target)
  scheme.save_as(project_path, name, true)
end

project.save
