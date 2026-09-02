# Testing and debugging lanes

require 'json'
require 'shellwords'

# Every available simulator of a platform, as `[runtime, device]` pairs.
def available_simulators(platform)
  JSON.parse(`xcrun simctl list devices available --json`)['devices']
      .select { |runtime, _| runtime.include?(platform) }
      .flat_map { |runtime, devices| devices.map { |device| [runtime, device] } }
end

# Newest available simulator of a given model, resolved to a UDID.
#
# A `name,OS=latest` destination is ambiguous whenever a device matches more than once (see the
# watch destination below), and the E2E lane needs the UDID anyway to erase the device first.
def newest_simulator(model, platform)
  newest = available_simulators(platform)
           .select { |_, device| device['name'] == model }
           .max_by { |runtime, _| runtime.scan(/\d+/).map(&:to_i) }
  UI.user_error!("No available #{platform} simulator named '#{model}'") if newest.nil?
  newest.last['udid']
end

desc 'Update the test cases from the fcm repo'
lane :update_notification_test_cases do
  bundle_directory = File.expand_path('../Tests/Shared/notification_test_cases.bundle')
  zip_file = Tempfile.new(['archive', '.zip'])

  FileUtils.rm_rf bundle_directory
  FileUtils.mkdir_p bundle_directory

  begin
    archive_url = 'https://github.com/home-assistant/mobile-apps-fcm-push/archive/refs/heads/master.zip'
    unzip_path = 'mobile-apps-fcm-push-master/functions/test/fixtures/legacy/*.json'

    sh("curl -L #{archive_url} -o #{zip_file.path}")
    sh("unzip -j #{zip_file.path} -d #{bundle_directory} '#{unzip_path}'")
  ensure
    zip_file.unlink
  end
end

lane :update_dsyms do
  directory = File.expand_path('dSYMs')
  FileUtils.mkdir_p directory

  download_dsyms(
    after_uploaded_date: Date.today.prev_day(7).iso8601,
    app_identifier: 'io.robbie.HomeAssistant',
    output_directory: directory
  )

  FileUtils.rm_r directory
end

desc 'Run tests'
lane :test do
  run_tests(
    project: 'HomeAssistant.xcodeproj',
    scheme: 'Tests-Unit',
    result_bundle: true,
    skip_package_dependencies_resolution: true,
    skip_detect_devices: true,
    # Run only the `test` action: `build test` compiles every SPM target twice
    # because the plain `build` action disables testability for packages.
    skip_build: true,
    xcargs: 'COMPILER_INDEX_STORE_ENABLE=NO',
    destination: 'platform=iOS Simulator,name=iPhone 17,OS=latest'
  )

  # The complication snapshot tests render the shared views on watchOS, so they run under the WatchApp
  # scheme on a watch simulator — the iOS run above can't reach them. A plain name,OS destination is
  # ambiguous here: CI pairs a watch to a phone, and a paired watch matches twice ("multiple devices
  # matched"). Which model gets paired varies per runner, so resolve the 46mm's UDID (the model the
  # reference images were recorded on) and target it by id, which is unambiguous even when paired.
  watch_model = 'Apple Watch Series 11 (46mm)'
  newest_watch = available_simulators('watchOS')
                 .select { |_, device| device['name'] == watch_model }
                 .max_by { |runtime, _| runtime.scan(/\d+/).map(&:to_i) }
  watch_destination =
    if newest_watch
      "platform=watchOS Simulator,id=#{newest_watch.last['udid']}"
    else
      "platform=watchOS Simulator,name=#{watch_model},OS=latest"
    end

  run_tests(
    project: 'HomeAssistant.xcodeproj',
    scheme: 'WatchApp',
    only_testing: ['HomeAssistant-WatchAppTests'],
    result_bundle: false,
    skip_package_dependencies_resolution: true,
    skip_detect_devices: true,
    skip_build: true,
    xcargs: 'COMPILER_INDEX_STORE_ENABLE=NO',
    destination: watch_destination
  )
end

desc 'Run the end-to-end onboarding test against a running Home Assistant'
lane :e2e do |options|
  url = options[:url] || 'http://localhost:8123'
  username = options[:username] || 'citest'
  password = options[:password] || 'h7jk99&U'
  model = options[:device] || 'iPhone 17'

  # Fail here rather than three minutes into a build if the instance is not usable: this walks the
  # same login exchange the app performs during onboarding.
  verify = File.expand_path('../../Tools/home_assistant_e2e_auth.py', __dir__)
  sh("python3 #{Shellwords.escape(verify)} --url #{Shellwords.escape(url)} " \
     "--username #{Shellwords.escape(username)} --password #{Shellwords.escape(password)} " \
     '--timeout 300 --require-component mobile_app')

  # The test starts from the welcome screen, so the app must not already have a server. Erasing is
  # also what puts the location and notification prompts back, which the flow answers on its way
  # through. This is why the lane never retries a failure: a second run would start onboarded.
  udid = newest_simulator(model, 'iOS')
  sh("xcrun simctl shutdown #{udid} || true")
  sh("xcrun simctl erase #{udid}")

  # `xcodebuild` forwards TEST_RUNNER_-prefixed variables into the test process with the prefix
  # stripped, which is how the flow learns where to point the app.
  ENV['TEST_RUNNER_E2E_HOME_ASSISTANT_URL'] = url
  ENV['TEST_RUNNER_E2E_HOME_ASSISTANT_USERNAME'] = username
  ENV['TEST_RUNNER_E2E_HOME_ASSISTANT_PASSWORD'] = password

  run_tests(
    project: 'HomeAssistant.xcodeproj',
    scheme: 'Tests-UI',
    result_bundle: true,
    skip_package_dependencies_resolution: true,
    skip_detect_devices: true,
    skip_build: true,
    xcargs: 'COMPILER_INDEX_STORE_ENABLE=NO',
    destination: "platform=iOS Simulator,id=#{udid}",
    output_directory: 'fastlane/test_output/e2e'
  )
end
