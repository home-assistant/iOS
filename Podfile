use_frameworks!
inhibit_all_warnings!

project 'HomeAssistant', 'Debug' => :debug, 'Release' => :release, 'Beta' => :release

def support_modules
  pod 'SwiftGen', '~> 6.5.0'
  pod 'SwiftLint', '0.54.0' # also update ci.yml GHA
  pod 'SwiftFormat/CLI', '0.53.1' # also update ci.yml GHA
end

if ENV['ONLY_SUPPORT_MODULES']
  # some of our CI scripts only need e.g. SwiftLint
  # this allows us to skip a lot of installation when unnecessary
  platform :ios, '15.0'
  support_modules
  workspace 'abstract.workspace'

  return self # rubocop:disable Lint/TopLevelReturnWithArgument
end

plugin 'cocoapods-acknowledgements'

pod 'Alamofire', '~> 5.8'
pod 'Communicator', git: 'https://github.com/zacwest/Communicator.git', branch: 'observation-memory-direct'
pod 'KeychainAccess'
pod 'ObjectMapper', git: 'https://github.com/tristanhimmelman/ObjectMapper.git', branch: 'master'
pod 'PromiseKit'
pod 'Improv-iOS', '~> 0.0.6'

pod 'RealmSwift'
pod 'UIColor_Hex_Swift'
pod 'Version'
pod 'XCGLogger'

# Keep Starscream reference even though HAKit already install it, because it defines our fork with the necessary fix
pod 'Starscream', git: 'https://github.com/bgoncal/starscream', branch: 'ha-URLSession-fix'
pod 'HAKit', git: 'https://github.com/home-assistant/HAKit.git', tag: '0.4.2'
pod 'HAKit/PromiseKit', git: 'https://github.com/home-assistant/HAKit.git', tag: '0.4.2'
pod 'HAKit/Mocks', git: 'https://github.com/home-assistant/HAKit.git', tag: '0.4.2'

def test_pods
  pod 'OHHTTPStubs/Swift'
end

def shared_fwk_pods
  pod 'Sodium', git: 'https://github.com/zacwest/swift-sodium.git', branch: 'xcode-14.0.1'
end

abstract_target 'iOS' do
  platform :ios, '15.0'

  pod 'MBProgressHUD', '~> 1.2.0'
  pod 'ReachabilitySwift'

  # fixes newer cocoapods search path issues for Clibsodium build failures
  shared_fwk_pods

  target 'Shared-iOS' do
    shared_fwk_pods
    pod 'ZIPFoundation', '~> 0.9'

    target 'Tests-Shared' do
      inherit! :complete
      test_pods
    end
  end

  target 'App' do
    pod 'CallbackURLKit'
    pod 'ColorPickerRow', git: 'https://github.com/EurekaCommunity/ColorPickerRow',
                          commit: 'fde095843bb8c08e8818097c51ed140373180790'
    pod 'CPDAcknowledgements', git: 'https://github.com/CocoaPods/CPDAcknowledgements', branch: 'master'
    pod 'Eureka', git: 'https://github.com/xmartlabs/Eureka', branch: 'master'

    pod 'FirebaseMessaging'

    pod 'lottie-ios'
    pod 'SwiftMessages'
    pod 'ViewRow', git: 'https://github.com/EurekaCommunity/ViewRow', branch: 'master'

    support_modules

    target 'Tests-App' do
      inherit! :search_paths
      test_pods
    end
  end

  target 'Extensions-Intents'
  target 'Extensions-Matter'
  target 'Extensions-NotificationContent'
  target 'Extensions-NotificationService'
  target 'Extensions-PushProvider'
  target 'Extensions-Share'
  target 'Extensions-Widgets'
end

abstract_target 'watchOS' do
  platform :watchos, '8.0'

  target 'Shared-watchOS' do
    shared_fwk_pods
  end

  target 'WatchExtension-Watch' do
    pod 'EMTLoadingIndicator', git: 'https://github.com/hirokimu/EMTLoadingIndicator', branch: 'master'
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '8.0'
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'

      config.build_settings['SWIFT_INSTALL_OBJC_HEADER'] = 'NO' unless target.name.include? 'Firebase'

      # disabled arch to stay under the 75 MB limit imposed by apple
      config.build_settings['EXCLUDED_ARCHS[sdk=watchos*]'] = 'arm64'

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
