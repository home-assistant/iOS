use_frameworks!
inhibit_all_warnings!

project 'HomeAssistant', 'Debug' => :debug, 'Release' => :release

abstract_target 'iOS' do
  platform :ios, '16.4'

  target 'Shared-iOS' do
    target 'Tests-Shared' do
      inherit! :complete
    end
  end

  target 'App' do
    target 'Tests-App' do
      inherit! :search_paths
    end
  end

  target 'SharedTesting'
  target 'Extensions-Intents'
  target 'Extensions-Matter'
  target 'Extensions-NotificationContent'
  target 'Extensions-NotificationService'
  target 'Extensions-PushProvider'
  target 'Extensions-Share'
  target 'Extensions-Widgets'
end

abstract_target 'watchOS' do
  platform :watchos, '9.0'

  target 'Shared-watchOS'

  target 'WatchApp'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '9.0'
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.4'

      config.build_settings['SWIFT_INSTALL_OBJC_HEADER'] = 'NO' unless target.name.include? 'Firebase'

      next unless config.name == 'Release'

      # cocoapods defaults to not stripping the frameworks it creates
      config.build_settings['STRIP_INSTALLED_PRODUCT'] = 'YES'
    end

    # Fix bundle targets' 'Signing Certificate' to 'Sign to Run Locally'
    # (catalyst fix)
    # rubocop:disable Style/Next
    if target.respond_to?(:product_type) && (target.product_type == 'com.apple.product-type.bundle')
      target.build_configurations.each do |config|
        config.build_settings['CODE_SIGN_IDENTITY[sdk=macosx*]'] = '-'
        config.build_settings['CODE_SIGNING_ALLOWED[sdk=iphoneos*]'] = 'NO'
      end
    end
    # rubocop:enable Style/Next
  end
end
