# Distributing from a developer Mac instead of GitHub Actions

require 'base64'
require 'digest'
require 'plist'
require 'securerandom'
require 'shellwords'
require 'tmpdir'

LOCAL_DISTRIBUTION_KEYCHAIN = 'HomeAssistant-Local-Distribution'.freeze

LOCAL_DISTRIBUTION_SIGNING = {
  'Apple Distribution' => { platforms: %w[ios mac], secret: 'DISTRIBUTION' },
  'Developer ID Application' => { platforms: %w[mac], secret: 'MAC_DEVELOPER_ID' },
  '3rd Party Mac Developer Installer' => { platforms: %w[mac], secret: 'MAC_DEVELOPER_INSTALLER' }
}.freeze

LOCAL_DISTRIBUTION_PLATFORMS = {
  'both' => %w[ios mac],
  'ios' => %w[ios],
  'mac' => %w[mac]
}.freeze

LOCAL_DISTRIBUTION_PROFILES = {
  'ios' => %w[iOS_App_Store__],
  'mac' => %w[Mac_App_Store__ Mac_Dev_ID__]
}.freeze

desc 'Distribute from this Mac, asking for what the Distribute workflow reads from GitHub secrets'
lane :local_distribution do |options|
  platforms = local_distribution_platforms(options[:platforms])
  local_distribution_xcode
  run_number = local_distribution_run_number(options[:run_number])
  local_distribution_credentials

  version_file = File.expand_path('../Configuration/Version.xcconfig')
  original_version = File.read(version_file)
  keychain = nil

  begin
    keychain = local_distribution_signing_keychain(platforms)
    import_provisioning_profiles
    local_distribution_check_profiles(platforms)

    set_version_info(
      version: get_xcconfig_marketing_version,
      build: "#{get_xcconfig_build_number.split('.').first}.#{run_number}"
    )

    platforms.each { |platform| sh("cd .. ; bundle exec fastlane #{platform} build") }

    UI.success('Uploaded. Artifacts are in build/ios and build/macos.')
    UI.success('Attach build/macos/home-assistant-mac.zip to the GitHub release.') if platforms.include?('mac')
  ensure
    File.write(version_file, original_version)
    delete_keychain(name: keychain) if keychain
  end
end

def local_distribution_prompt
  previous = ENV.fetch('FASTLANE_HIDE_TIMESTAMP', nil)
  ENV['FASTLANE_HIDE_TIMESTAMP'] = 'true'
  yield
ensure
  ENV['FASTLANE_HIDE_TIMESTAMP'] = previous
end

def local_distribution_ask(name, text, secure: false)
  value = ENV.fetch(name, '').strip
  return value unless value.empty?

  label = "#{text} (#{name}):"
  value = local_distribution_prompt { secure ? UI.password(label) : UI.input(label) }.strip
  UI.user_error!("#{text} is required.") if value.empty?
  ENV[name] = value
end

def local_distribution_platforms(requested)
  if requested
    return LOCAL_DISTRIBUTION_PLATFORMS.fetch(requested.to_s) do
      UI.user_error!("Unknown platform '#{requested}', use ios, mac or both.")
    end
  end

  loop do
    answer = local_distribution_prompt { UI.input('Which apps should be distributed? Type ios, mac or both [both]:') }
    answer = answer.downcase.empty? ? 'both' : answer.downcase
    return LOCAL_DISTRIBUTION_PLATFORMS[answer] if LOCAL_DISTRIBUTION_PLATFORMS.key?(answer)
  end
end

def local_distribution_xcode_label(app)
  info = Plist.parse_xml(File.join(app, 'Contents/version.plist'))
  "#{File.basename(app, '.app')} (#{info['CFBundleShortVersionString']}, build #{info['ProductBuildVersion']})"
end

def local_distribution_xcode_app
  app = File.expand_path('../..', ENV.fetch('DEVELOPER_DIR', '/'))
  File.exist?(File.join(app, 'Contents/version.plist')) ? app : nil
end

def local_distribution_clean_path(answer)
  File.expand_path(answer.strip.gsub('\ ', ' ').delete("'\""))
end

def local_distribution_xcode_at(answer)
  path = local_distribution_clean_path(answer)
  path = File.expand_path('../..', path) if path.end_with?('/Contents/Developer')
  File.exist?(File.join(path, 'Contents/version.plist')) ? path : nil
end

def local_distribution_choose_xcode
  loop do
    answer = local_distribution_prompt { UI.input('Xcode path (e.g. /Applications/Xcode.app):') }
    app = local_distribution_xcode_at(answer)
    return File.join(app, 'Contents/Developer') if app
  end
end

def local_distribution_xcode
  ENV['DEVELOPER_DIR'] = local_distribution_choose_xcode unless local_distribution_xcode_app
  UI.important("Building with #{local_distribution_xcode_label(local_distribution_xcode_app)}")
end

def local_distribution_latest_run
  number = `gh run list --workflow distribute.yml --limit 1 --json number --jq '.[0].number' 2>/dev/null`.strip
  number.match?(/\A\d+\z/) ? number.to_i : nil
end

def local_distribution_run_number(requested)
  text = 'Distribute run number reserved for this build (start and cancel a Distribute run on GitHub to reserve one):'
  number = (requested || local_distribution_prompt { UI.input(text) }).to_s.strip
  latest = local_distribution_latest_run
  UI.user_error!("'#{number}' is not a run number.") unless number.match?(/\A\d+\z/)
  UI.user_error!("Run #{number} doesn't exist yet. Reserve it on GitHub first.") if latest && number.to_i > latest
  number
end

def local_distribution_credentials
  local_distribution_ask('HOMEASSISTANT_TEAM_ID', 'Apple Developer team ID')
  local_distribution_ask('HOMEASSISTANT_APPLE_ID', 'Apple ID that uploads and notarizes')
  password = local_distribution_ask('HOMEASSISTANT_APP_STORE_CONNECT_PASSWORD',
                                    'App-specific password of that Apple ID', secure: true)

  ENV['FASTLANE_DONT_STORE_PASSWORD'] = '1'
  ENV['FASTLANE_PASSWORD'] = password
  ENV['FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD'] = password
  ENV['FASTLANE_XCODEBUILD_SETTINGS_TIMEOUT'] ||= '180'
  ENV['FASTLANE_XCODE_LIST_TIMEOUT'] ||= '60'
  ENV['LANG'] = ENV['LC_ALL'] = 'en_US.UTF-8'
end

def local_distribution_identities
  `security find-identity -v`.scan(/\) ([0-9A-F]{40}) "([^"]+)"/).uniq
end

def local_distribution_missing_identities(platforms)
  team = ENV.fetch('HOMEASSISTANT_TEAM_ID')
  identities = local_distribution_identities
  LOCAL_DISTRIBUTION_SIGNING.filter_map do |name, info|
    next unless info[:platforms].intersect?(platforms)

    matches = identities.select { |_, label| label.start_with?("#{name}:") && label.end_with?("(#{team})") }
    UI.user_error!("#{matches.count} valid '#{name}' identities for #{team}; keep only one.") if matches.count > 1
    name if matches.empty?
  end
end

def local_distribution_signing_keychain(platforms)
  missing = local_distribution_missing_identities(platforms)
  return nil if missing.empty?

  keychain_password = SecureRandom.hex
  create_keychain(name: LOCAL_DISTRIBUTION_KEYCHAIN, password: keychain_password,
                  timeout: 3600, unlock: true, add_to_search_list: true)
  missing.each { |name| local_distribution_import_p12(name, keychain_password) }
  still_missing = local_distribution_missing_identities(platforms)
  UI.user_error!("Still no valid identity for: #{still_missing.join(', ')}") unless still_missing.empty?
  LOCAL_DISTRIBUTION_KEYCHAIN
end

def local_distribution_p12_data(name, secret)
  encoded = ENV.fetch("P12_VALUE_#{secret}", '')
  return Base64.decode64(encoded) unless encoded.empty?

  label = "Path to the #{name} .p12, or to a text file holding its base64 (P12_VALUE_#{secret}):"
  answer = local_distribution_prompt { UI.input(label) }
  data = File.binread(local_distribution_clean_path(answer))
  data.start_with?("\x30".b) ? data : Base64.decode64(data)
end

def local_distribution_import_p12(name, keychain_password)
  secret = LOCAL_DISTRIBUTION_SIGNING.fetch(name)[:secret]
  path = File.join(Dir.tmpdir, "local-distribution-#{SecureRandom.hex(4)}.p12")
  File.binwrite(path, local_distribution_p12_data(name, secret))
  password = local_distribution_ask("P12_KEY_#{secret}", "Password of the #{name} .p12", secure: true)
  import_certificate(certificate_path: path, certificate_password: password,
                     keychain_name: LOCAL_DISTRIBUTION_KEYCHAIN, keychain_password: keychain_password)
ensure
  FileUtils.rm_f(path) if path
end

def local_distribution_profile_problem(file, identity_shas)
  profile = Plist.parse_xml(`security cms -D -i #{file.shellescape} 2>/dev/null`)
  name = File.basename(file)
  return "#{name}: expired on #{profile['ExpirationDate']}" if profile['ExpirationDate'].to_time < Time.now

  certificates = profile['DeveloperCertificates'].map { |cert| Digest::SHA1.hexdigest(cert.string).upcase }
  "#{name}: made for a certificate with no valid identity here" unless certificates.intersect?(identity_shas)
end

def local_distribution_check_profiles(platforms)
  identity_shas = local_distribution_identities.map(&:first)
  problems = platforms.flat_map { |platform| LOCAL_DISTRIBUTION_PROFILES.fetch(platform) }
                      .flat_map { |prefix| Dir["../Configuration/Provisioning/#{prefix}*"] }
                      .filter_map { |file| local_distribution_profile_problem(file, identity_shas) }
  UI.user_error!("These provisioning profiles can't sign the release:\n#{problems.join("\n")}") unless problems.empty?
end
