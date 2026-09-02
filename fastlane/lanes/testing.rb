# Testing and debugging lanes

require 'json'

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
  watch_devices = JSON.parse(`xcrun simctl list devices available --json`)['devices']
  newest_watch = watch_devices.select { |runtime, _| runtime.include?('watchOS') }
                              .flat_map { |runtime, devices| devices.map { |device| [runtime, device] } }
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
