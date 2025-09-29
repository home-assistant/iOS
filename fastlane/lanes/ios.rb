# iOS platform specific lanes

platform :ios do
  private_lane :create_archive do
    setup_ha_ci if is_ci
    specifiers = provisioning_profile_specifiers(sdk: 'iphoneos')
    ipa_path = build_ios_app(
      export_method: 'app-store',
      skip_package_dependencies_resolution: true,
      skip_profile_detection: true,
      disable_xcpretty: true,
      output_directory: './build/ios',
      export_options: {
        signingStyle: 'manual',
        provisioningProfiles: specifiers
      }
    )
    ipa_path
  end

  lane :build do
    ipa_path = create_archive
    upload_binary_to_apple(
      type: 'ios',
      path: ipa_path
    )
  end

  lane :size do
    create_archive
  end
end
