# Provisioning profile management lanes

lane :download_provisioning_profiles do
  ENV['FASTLANE_PASSWORD'] = ENV.fetch('HOMEASSISTANT_APP_STORE_CONNECT_PASSWORD', nil)
  ENV['FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD'] = ENV.fetch('HOMEASSISTANT_APP_STORE_CONNECT_PASSWORD', nil)
  ENV['FASTLANE_SESSION'] = ENV.fetch('HOMEASSISTANT_FASTLANE_SESSION', nil)
  ENV['FASTLANE_USER'] = ENV.fetch('HOMEASSISTANT_APPLE_ID', nil)

  # rubocop:disable Layout/LineLength
  # Disabled until sigh can handle Apple Distribution certs again
  # sh('fastlane', 'sigh', 'repair', '--username', ENV.fetch('FASTLANE_USER', nil), '--output_path', '../Configuration/Provisioning')
  sh('fastlane', 'sigh', 'download_all', '--username', ENV.fetch('FASTLANE_USER', nil), '--output_path', '../Configuration/Provisioning')
  # rubocop:enable Layout/LineLength
end

lane :import_provisioning_profiles do
  directory = '../Configuration/Provisioning'

  Dir.children(directory).each do |file|
    next if file.start_with?('.')

    install_provisioning_profile(path: File.expand_path(File.join(directory, file)))
  end
end

private_lane :provisioning_profile_specifiers do |options|
  # gym doesn't parse the provisioning profile specifier, so we need to do it ourselves
  all_targets_result = sh([
    'xcodebuild',
    '2>/dev/null', # this command started outputting warnings in Xcode 12.5
    '-json',
    '-showBuildSettings',
    '-sdk', options[:sdk],
    '-project', '../HomeAssistant.xcodeproj',
    '-scheme', 'App-Release',
    '-list'
  ] + [], log: false)
  all_targets = JSON.parse(all_targets_result)['project']['targets'].map { |t| "-target #{t}" }

  settings_result = sh([
    'xcodebuild',
    '2>/dev/null', # this command started outputting warnings in Xcode 12.5
    '-json',
    '-showBuildSettings',
    '-sdk', options[:sdk],
    '-project', '../HomeAssistant.xcodeproj'
  ] + all_targets, log: false)

  settings = JSON.parse(settings_result)

  specifiers = {}
  settings.each do |target_info|
    specifier = target_info['buildSettings']['PROVISIONING_PROFILE_SPECIFIER']
    bundle_identifier = target_info['buildSettings']['PRODUCT_BUNDLE_IDENTIFIER']
    next unless specifier && bundle_identifier

    specifiers[bundle_identifier] = specifier
  end

  specifiers
end
