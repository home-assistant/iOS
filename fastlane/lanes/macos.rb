# macOS platform specific lanes

platform :mac do
  lane :build do
    setup_ha_ci if is_ci

    specifiers = provisioning_profile_specifiers(sdk: 'macosx')
    developer_id_app_path = build_mac_app(
      export_method: 'developer-id',
      skip_package_dependencies_resolution: true,
      skip_profile_detection: true,
      skip_package_pkg: true,
      disable_xcpretty: true,
      output_directory: './build/macos',
      export_options: {
        signingStyle: 'manual',
        provisioningProfiles: specifiers
      }
    )
    app_store_pkg_path = build_mac_app(
      archive_path: lane_context[SharedValues::XCODEBUILD_ARCHIVE],
      export_method: 'app-store',
      skip_package_dependencies_resolution: true,
      skip_profile_detection: true,
      skip_build_archive: true,
      skip_package_pkg: false,
      output_directory: './build/macos',
      export_options: {
        signingStyle: 'manual',
        provisioningProfiles: specifiers.transform_values { |v| v.sub('Mac Dev ID', 'Mac App Store') }
      }
    )

    notarize_attempts = 0

    begin
      notarize(
        package: developer_id_app_path,
        # not the _app_ bundle id, just an id that notarize uses for referencing
        bundle_id: 'io.home-assistant.fastlane.developer-id',
        verbose: true
      )
    rescue StandardError => e
      puts "Failed with #{e}; retrying notarize in a few seconds..."

      sleep 5

      # retry a few times, then give up
      notarize_attempts += 1

      retry if notarize_attempts <= 3
      raise e
    end

    sh(
      'ditto',
      '-c',
      '-k',
      '--sequesterRsrc',
      '--keepParent',
      File.expand_path(developer_id_app_path),
      '../build/macos/home-assistant-mac.zip'
    )
    upload_binary_to_apple(
      type: 'osx',
      path: app_store_pkg_path
    )
  end
end
