Pod::Spec.new do |spec|
  spec.name                  = 'SudoProfiles'
  spec.version               = '5.4.2'
  spec.author                = { 'Sudo Platform Engineering' => 'sudoplatform-engineering@anonyome.com' }
  spec.homepage              = 'https://sudoplatform.com'
  spec.summary               = 'Profiles SDK for the Sudo Platform by Anonyome Labs.'
  spec.license               = { :type => 'Apache License, Version 2.0',  :file => 'LICENSE' }
  spec.source                = { :git => 'https://github.com/sudoplatform/sudo-profiles-ios.git', :tag => "v#{spec.version}" }
  spec.source_files          = 'SudoProfiles/*.swift'
  spec.ios.deployment_target = '11.0'
  spec.requires_arc          = true
  spec.swift_version         = '5.0'

  spec.dependency 'SudoUser', '~> 7.8'
  spec.dependency 'SudoApiClient', '~> 1.3'
  spec.dependency 'SudoLogging', '~> 0.2'
end
