# Uncomment this line to define a global platform for your project
platform :ios, "15.0"
use_frameworks!

# Ignore all warnings from pods.
inhibit_all_warnings!
use_modular_headers!

source 'https://github.com/CocoaPods/Specs.git'

target "SudoProfiles" do
  podspec :name => 'SudoProfiles'

  target "SudoProfilesTests" do
    podspec :name => 'SudoProfiles'
  end

  target "SudoProfilesIntegrationTests" do
    podspec :name => 'SudoProfiles'
    pod 'SudoEntitlements'
    pod 'SudoEntitlementsAdmin'
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
