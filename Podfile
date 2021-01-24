use_frameworks!
inhibit_all_warnings!

project 'HomeAssistant', 'Debug' => :debug, 'Release' => :release, 'Beta' => :release
plugin 'cocoapods-acknowledgements'

system("./Tools/BuildMaterialDesignIconsFont.sh")

pod 'Alamofire', '~> 5.0'
pod 'Communicator', '~> 4.0'
pod 'KeychainAccess'
pod 'ObjectMapper', :git => 'https://github.com/tristanhimmelman/ObjectMapper.git', :branch => 'master'
pod 'PromiseKit'
pod 'RealmSwift', :podspec => 'Configuration/Podspecs/Realm.podspec.json'
pod 'Sentry'
pod 'UIColor_Hex_Swift'
pod 'Version'
pod 'XCGLogger'

# Set FONT_PATH and CUSTOM_FONT_NAME variables for MDI
#puts "Setting FONT_PATH to '#{File.expand_path('./Tools/MaterialDesignIcons.ttf')}'"
#ENV['FONT_PATH'] = File.expand_path('./Tools/MaterialDesignIcons.ttf')
#puts "Setting CUSTOM_FONT_NAME to 'MaterialDesignIcons'"
#ENV['CUSTOM_FONT_NAME'] = 'MaterialDesignIcons'
#pod 'Iconic', :git => 'https://github.com/home-assistant/Iconic.git', :branch => 'master'

def test_pods
    pod 'OHHTTPStubs/Swift'
end

def shared_fwk_pods
    pod 'Sodium', :git => 'https://github.com/jedisct1/swift-sodium.git', :branch => 'master'
end

abstract_target 'iOS' do
    platform :ios, '12.0'

    pod 'MBProgressHUD', '~> 1.2.0'
    pod 'ReachabilitySwift'

    target 'Shared-iOS' do
        shared_fwk_pods

        target 'Tests-Shared' do
            inherit! :complete
            test_pods
        end
    end

    target 'App' do
        pod 'CallbackURLKit'
        pod 'ColorPickerRow', :git => 'https://github.com/EurekaCommunity/ColorPickerRow', :branch => 'master'
        pod 'CPDAcknowledgements', :git => 'https://github.com/CocoaPods/CPDAcknowledgements', :branch => 'master'
        pod 'Eureka'
        pod 'Firebase', :podspec => 'Configuration/Podspecs/Firebase.podspec.json'
        pod 'Lokalise', '~> 0.10.0'
        pod 'lottie-ios'
        pod 'SimulatorStatusMagic', :configurations => ['Debug']
        pod 'SwiftGen', '~> 6.4.0'
        pod 'SwiftLint'
        pod 'SwiftMessages'
        pod 'ViewRow', :git => 'https://github.com/EurekaCommunity/ViewRow', :branch => 'master'
        pod 'ZIPFoundation', '~> 0.9'

        target 'Tests-App' do
            inherit! :search_paths
            test_pods
        end
    end

    target 'Extensions-Intents'
    target 'Extensions-NotificationContent'
    target 'Extensions-NotificationService'
    target 'Extensions-Share'
    target 'Extensions-Today'
    target 'Extensions-Widgets'
end

abstract_target 'watchOS' do
    platform :watchos, '5.0'

    target 'Shared-watchOS' do
        shared_fwk_pods
    end

    target 'WatchExtension-Watch' do
        pod 'EMTLoadingIndicator', :git => 'https://github.com/hirokimu/EMTLoadingIndicator', :branch => 'master'
    end
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            xcconfig_path = config.base_configuration_reference.real_path
            xcconfig = File.read(xcconfig_path)
            xcconfig.sub!('-framework "Lokalise"', '')
            File.open(xcconfig_path, "w") { |file| file << xcconfig }

            config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '5.0'
            config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '11.0'
            config.build_settings['SWIFT_INSTALL_OBJC_HEADER'] = 'NO'
        end

        # Fix bundle targets' 'Signing Certificate' to 'Sign to Run Locally'
        # (catalyst fix)
        if target.respond_to?(:product_type) and target.product_type == "com.apple.product-type.bundle"
            target.build_configurations.each do |config|
                config.build_settings['CODE_SIGN_IDENTITY[sdk=macosx*]'] = '-'
            end
        end
    end
end
