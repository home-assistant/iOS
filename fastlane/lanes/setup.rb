# Setup and configuration lanes

before_all do
  setup
end

private_lane :setup do
  # Setup environment variables for Fastlane
  ENV['FASTLANE_USER'] = ENV.fetch('HOMEASSISTANT_APPLE_ID', nil)
  ENV['FASTLANE_ITC_TEAM_ID'] = ENV.fetch('HOMEASSISTANT_APP_STORE_CONNECT_TEAM_ID', nil)
  ENV['FASTLANE_TEAM_ID'] = ENV.fetch('HOMEASSISTANT_TEAM_ID', nil)

  ENV['DELIVER_USERNAME'] = ENV.fetch('HOMEASSISTANT_APPLE_ID', nil)
  ENV['FL_NOTARIZE_ASC_PROVIDER'] = ENV.fetch('HOMEASSISTANT_TEAM_ID', nil)
  ENV['FL_NOTARIZE_USERNAME'] = ENV.fetch('HOMEASSISTANT_APPLE_ID', nil)

  # Set Lokalise environment variables
  ENV['LOKALISE_API_TOKEN'] = ENV.fetch('HOMEASSISTANT_LOKALIZE_TOKEN', nil)
  ENV['LOKALISE_PROJECT_ID'] = ENV.fetch('HOMEASSISTANT_LOKALIZE_PROJECT_ID', nil)
  ENV['LOKALISE_PROJECT_ID_FRONTEND'] = ENV.fetch('HOMEASSISTANT_LOKALIZE_PROJECT_FRONTEND', nil)
  ENV['LOKALISE_PROJECT_ID_CORE'] = ENV.fetch('HOMEASSISTANT_LOKALIZE_PROJECT_CORE', nil)

  app_store_connect_api_key if ENV['APP_STORE_CONNECT_API_KEY_KEY']
end

desc 'Setup Continous Integration'
lane :setup_ha_ci do
  raise 'No github run number specified' unless ENV['GITHUB_RUN_NUMBER']

  set_version_info(
    version: get_xcconfig_marketing_version,
    build: get_xcconfig_build_number + '.' + ENV.fetch('GITHUB_RUN_NUMBER', nil) # rubocop:disable Style/StringConcatenation
  )

  # we only expose these keys in ci when appropriate
  ENV['FASTLANE_DONT_STORE_PASSWORD'] = '1'
  ENV['FASTLANE_PASSWORD'] = ENV.fetch('HOMEASSISTANT_APP_STORE_CONNECT_PASSWORD', nil)
  ENV['FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD'] = ENV.fetch('HOMEASSISTANT_APP_STORE_CONNECT_PASSWORD', nil)

  keychain_name = 'HomeAssistant-Keychain'
  keychain_password = SecureRandom.hex

  begin
    delete_keychain(name: keychain_name)
  rescue StandardError
    # we don't care if it didn't exist yet
  end

  create_keychain(
    name: keychain_name,
    password: keychain_password,
    timeout: 3600,
    unlock: true,
    add_to_search_list: true
  )

  KeyAndValue = Struct.new(:key, :value) # rubocop:disable Lint/ConstantDefinitionInBlock

  [
    KeyAndValue.new(ENV.fetch('P12_KEY_IOS_APP_STORE', nil), ENV.fetch('P12_VALUE_IOS_APP_STORE', nil)),
    KeyAndValue.new(ENV.fetch('P12_KEY_MAC_APP_STORE', nil), ENV.fetch('P12_VALUE_MAC_APP_STORE', nil)),
    KeyAndValue.new(ENV.fetch('P12_KEY_MAC_DEVELOPER_ID', nil), ENV.fetch('P12_VALUE_MAC_DEVELOPER_ID', nil))
  ].each do |info|
    tmp_file = '/tmp/import.p12'
    File.write(tmp_file, Base64.decode64(info.value))

    import_certificate(
      certificate_path: tmp_file,
      certificate_password: info.key,
      keychain_name: keychain_name,
      keychain_password: keychain_password
    )

    FileUtils.rm(tmp_file)
  end

  import_provisioning_profiles
end
