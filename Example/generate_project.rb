#!/usr/bin/env ruby
# Regenerates Example/NavigatorUIExample.xcodeproj. Requires the `xcodeproj` gem.
#   ruby Example/generate_project.rb
require 'fileutils'
require 'xcodeproj'

root = File.expand_path(__dir__)
project_path = File.join(root, 'NavigatorUIExample.xcodeproj')
FileUtils.rm_rf(project_path)
project = Xcodeproj::Project.new(project_path)

IOS = '16.0'
common = {
  'SWIFT_VERSION' => '6.0',
  'IPHONEOS_DEPLOYMENT_TARGET' => IOS,
  'SDKROOT' => 'iphoneos',
  'SUPPORTED_PLATFORMS' => 'iphoneos iphonesimulator',
  'TARGETED_DEVICE_FAMILY' => '1,2',
  'GENERATE_INFOPLIST_FILE' => 'YES',
  'CODE_SIGN_STYLE' => 'Automatic',
  'CODE_SIGNING_ALLOWED' => 'NO',
  'CURRENT_PROJECT_VERSION' => '1',
  'MARKETING_VERSION' => '1.0'
}

# Local package dependency on the repository root.
package = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
package.relative_path = '..'
project.root_object.package_references << package

def add_package_product(project, target, package)
  dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dependency.product_name = 'NavigatorUI'
  dependency.package = package
  target.package_product_dependencies << dependency
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dependency
  target.frameworks_build_phase.files << build_file
end

# App target
app = project.new_target(:application, 'NavigatorUIExample', :ios, IOS)
app.build_configurations.each do |config|
  config.build_settings.merge!(common)
  config.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER' => 'dev.navigatorui.example',
    'INFOPLIST_FILE' => 'NavigatorUIExample/Info.plist',
    'INFOPLIST_KEY_UILaunchScreen_Generation' => 'YES',
    'ENABLE_PREVIEWS' => 'YES'
  )
end
group = project.main_group.new_group('NavigatorUIExample', 'NavigatorUIExample')
Dir[File.join(root, 'NavigatorUIExample', '*.swift')].sort.each do |file|
  app.add_file_references([group.new_file(File.basename(file))])
end
group.new_file('Info.plist')
add_package_product(project, app, package)

# Unit tests hosted by the app. They compile the package's own test sources, so the same tests run
# headless (package scheme) and inside a real app with a window scene (this scheme).
tests = project.new_target(:unit_test_bundle, 'NavigatorUIExampleTests', :ios, IOS)
tests.add_dependency(app)
tests.build_configurations.each do |config|
  config.build_settings.merge!(common)
  config.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER' => 'dev.navigatorui.example.tests',
    'TEST_HOST' => '$(BUILT_PRODUCTS_DIR)/NavigatorUIExample.app/NavigatorUIExample',
    'BUNDLE_LOADER' => '$(TEST_HOST)',
    'ENABLE_TESTING_SEARCH_PATHS' => 'YES'
  )
end
test_group = project.main_group.new_group('PackageTests', '../Tests/NavigatorUITests')
Dir[File.join(root, '..', 'Tests', 'NavigatorUITests', '*.swift')].sort.each do |file|
  tests.add_file_references([test_group.new_file(File.basename(file))])
end
add_package_product(project, tests, package)

# UI tests that drive the real app (back button, swipe-back, sheets, URLs).
ui_tests = project.new_target(:ui_test_bundle, 'NavigatorUIExampleUITests', :ios, IOS)
ui_tests.add_dependency(app)
ui_tests.build_configurations.each do |config|
  config.build_settings.merge!(common)
  config.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER' => 'dev.navigatorui.example.uitests',
    'TEST_TARGET_NAME' => 'NavigatorUIExample'
  )
end
ui_group = project.main_group.new_group('NavigatorUIExampleUITests', 'NavigatorUIExampleUITests')
Dir[File.join(root, 'NavigatorUIExampleUITests', '*.swift')].sort.each do |file|
  ui_tests.add_file_references([ui_group.new_file(File.basename(file))])
end

# Scheme that builds the app and runs both test bundles.
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_test_target(tests)
scheme.add_test_target(ui_tests)
scheme.set_launch_target(app)
scheme.save_as(project_path, 'NavigatorUIExample', true)

project.save
puts "Generated #{project_path}"
