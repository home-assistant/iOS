# Testing and debugging lanes

require 'json'
require 'open3'
require 'shellwords'

# Simulator runtimes of a platform that can actually boot. `simctl` keeps listing a runtime, and the
# devices on it, as available after the runtime's files are gone from the runner, and installing on
# one of those devices then fails with "runtime path not found".
def usable_runtimes(platform)
  JSON.parse(`xcrun simctl list runtimes available --json`)['runtimes']
      .select { |runtime| runtime['identifier'].start_with?("com.apple.CoreSimulatorRuntime.#{platform}-") }
      .select { |runtime| runtime['bundlePath'].nil? || File.directory?(runtime['bundlePath']) }
end

# Every available simulator of a platform on a usable runtime, as `[runtime, device]` pairs.
def available_simulators(platform)
  runtimes = usable_runtimes(platform).map { |runtime| runtime['identifier'] }
  JSON.parse(`xcrun simctl list devices available --json`)['devices']
      .slice(*runtimes)
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

# Newest usable runtime of a platform, downloading the platform's runtime when the runner has none.
def newest_usable_runtime(platform)
  sh('xcodebuild', '-downloadPlatform', platform) if usable_runtimes(platform).empty?
  newest = usable_runtimes(platform).max_by { |runtime| runtime['version'].split('.').map(&:to_i) }
  UI.user_error!("No usable #{platform} simulator runtime") if newest.nil?
  newest
end

# Makes a simulator of the given model on a runtime, resolved to its UDID.
def create_simulator(model, runtime)
  device_type = runtime['supportedDeviceTypes'].find { |type| type['name'] == model }
  UI.user_error!("#{runtime['name']} has no simulator named '#{model}'") if device_type.nil?
  udid, status = Open3.capture2('xcrun', 'simctl', 'create', model, device_type['identifier'], runtime['identifier'])
  UI.user_error!("Couldn't create a '#{model}' simulator on #{runtime['name']}") unless status.success?
  udid.strip
end

# A simulator of the given watch model on the newest usable watchOS runtime, resolved to a UDID.
#
# Runner images ship the watch pre-made on a single runtime, and some runners come up without that
# runtime's files, so neither the runtime nor the device on it can be taken for granted: download the
# runtime when none is usable, and make the device when the runtime has none.
def watch_simulator(model)
  runtime = newest_usable_runtime('watchOS')
  existing = available_simulators('watchOS')
             .find { |identifier, device| identifier == runtime['identifier'] && device['name'] == model }
  existing ? existing.last['udid'] : create_simulator(model, runtime)
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
  # The complication snapshot tests render the shared views on watchOS, so they run under the WatchApp
  # scheme on a watch simulator — the iOS run below can't reach them. A plain name,OS destination is
  # ambiguous here: CI pairs a watch to a phone, and a paired watch matches twice ("multiple devices
  # matched"), so the watch is targeted by UDID, which is unambiguous even when paired. The references
  # are rendered from the view rather than from the screen, so the model only has to be one the
  # runtime supports. Resolved up front so a runner that has to download the runtime and can't fails
  # before the long iOS run rather than after it.
  watch_destination = "platform=watchOS Simulator,id=#{watch_simulator('Apple Watch Series 12 (46mm)')}"

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

  run_tests(
    project: 'HomeAssistant.xcodeproj',
    scheme: 'WatchApp',
    only_testing: ['HomeAssistant-WatchAppTests'],
    parallel_testing: false,
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

  # Unlike the unit test lanes, this one builds: a UI test bundle is run against a separate app,
  # and the bare `test` action cannot resolve `UITargetAppPath` for an app that was never built.
  run_tests(
    project: 'HomeAssistant.xcodeproj',
    scheme: 'Tests-UI',
    # The scheme also holds `HomeAssistantUITests`, the fastlane screenshot flow, which expects
    # notification fixtures this lane does not set up.
    only_testing: ['Tests-UI/OnboardingE2ETests'],
    result_bundle: true,
    skip_package_dependencies_resolution: true,
    skip_detect_devices: true,
    xcargs: 'COMPILER_INDEX_STORE_ENABLE=NO',
    destination: "platform=iOS Simulator,id=#{udid}",
    output_directory: 'fastlane/test_output/e2e'
  )
end
