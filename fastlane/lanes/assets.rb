# Asset generation and management lanes

desc 'Generate proper icons for all build trains'
lane :icons do
  appicon(appicon_path: 'Sources/App/Resources/Assets.xcassets', appicon_image_file: 'icons/dev.png',
          appicon_name: 'AppIcon.dev.appiconset', appicon_devices: %i[ipad iphone ios_marketing macos])
  appicon(appicon_path: 'Sources/App/Resources/Assets.xcassets', appicon_image_file: 'icons/beta.png',
          appicon_name: 'AppIcon.beta.appiconset', appicon_devices: %i[ipad iphone ios_marketing macos])
  appicon(appicon_path: 'Sources/App/Resources/Assets.xcassets', appicon_image_file: 'icons/release.png',
          appicon_devices: %i[ipad iphone ios_marketing macos])

  appicon(appicon_path: 'WatchApp/Assets.xcassets', appicon_image_file: 'icons/dev.png',
          appicon_name: 'WatchIcon.dev.appiconset', appicon_devices: %i[watch watch_marketing])
  appicon(appicon_path: 'WatchApp/Assets.xcassets', appicon_image_file: 'icons/beta.png',
          appicon_name: 'WatchIcon.beta.appiconset', appicon_devices: %i[watch watch_marketing])
  appicon(appicon_path: 'WatchApp/Assets.xcassets', appicon_image_file: 'icons/release.png',
          appicon_name: 'WatchIcon.appiconset', appicon_devices: %i[watch watch_marketing])
end

desc 'Update switftgen input/output files'
lane :update_swiftgen_config do
  # rubocop:disable Layout/LineLength
  sh('cd ../ && ./Pods/SwiftGen/bin/swiftgen config generate-xcfilelists --inputs swiftgen.yml.file-list.in --outputs swiftgen.yml.file-list.out')
  # rubocop:enable Layout/LineLength
end