require 'fileutils'
require 'xcodeproj'

fixture_dir = File.expand_path(__dir__)
project_path = File.join(fixture_dir, 'Consumer.xcodeproj')
FileUtils.rm_rf(project_path)

project = Xcodeproj::Project.new(project_path)
sources_group = project.main_group.new_group('Sources', 'Sources')

targets = {
  'ObjCConsumer' => 'ObjCConsumer/main.m',
  'SwiftConsumer' => 'SwiftConsumer/App.swift',
  'SwiftUIConsumer' => 'SwiftUIConsumer/App.swift'
}

targets.each do |name, relative_source|
  target = project.new_target(:application, name, :ios, '15.0')
  source_reference = sources_group.new_file(relative_source)
  target.add_file_references([source_reference])

  target.build_configurations.each do |configuration|
    configuration.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    configuration.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
    configuration.build_settings['CURRENT_PROJECT_VERSION'] = '1'
    configuration.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    configuration.build_settings['MARKETING_VERSION'] = '1.0'
    configuration.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "com.guance.consumer.#{name.downcase}"
    configuration.build_settings['SWIFT_VERSION'] = '5.0' unless name == 'ObjCConsumer'
  end

  scheme = Xcodeproj::XCScheme.new
  scheme.add_build_target(target)
  scheme.set_launch_target(target)
  scheme.save_as(project_path, name, true)
end

project.save
