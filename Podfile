# Uncomment this line to define a global platform for your project
platform :ios, '11.4'
# Uncomment this line if you're using Swift
use_frameworks!
inhibit_all_warnings!

plugin 'cocoapods-acknowledgements'

if not File.exist?("Tools/MaterialDesignIcons.ttf")
    puts "Didn't find Tools/MaterialDesignIcons.ttf, downloading and building now"
    system("./Tools/BuildMaterialDesignIconsFont.sh")
else
    puts "Tools/MaterialDesignIcons.ttf already exists"
end

# Set FONT_PATH and CUSTOM_FONT_NAME variables for MDI
puts "Setting FONT_PATH to '#{File.expand_path('./Tools/MaterialDesignIcons.ttf')}'"
ENV['FONT_PATH'] = File.expand_path('./Tools/MaterialDesignIcons.ttf')
puts "Setting CUSTOM_FONT_NAME to 'MaterialDesignIcons'"
ENV['CUSTOM_FONT_NAME'] = 'MaterialDesignIcons'

def shared_pods
    pod 'Alamofire', '~> 4.0'
    pod 'Communicator', '~> 3.3.0'
    pod 'DeviceKit'
    #pod 'Iconic', :git => 'https://github.com/home-assistant/Iconic.git', :branch => 'master'
    pod 'KeychainAccess'
    pod 'ObjectMapper', :git => 'https://github.com/tristanhimmelman/ObjectMapper.git', :branch => 'master'
    pod 'PromiseKit'
    pod 'UIColor_Hex_Swift'
    pod 'Version'
    pod 'XCGLogger'
end

def shared_tests
    pod 'OHHTTPStubs/Swift'
end

def ios_shared_pods
    shared_pods

    pod 'ReachabilitySwift'
end

target 'HomeAssistant' do
    ios_shared_pods

    pod 'CallbackURLKit'
    pod 'ColorPickerRow', :git => 'https://github.com/EurekaCommunity/ColorPickerRow', :branch => 'master'
    pod 'CPDAcknowledgements', :git => 'https://github.com/CocoaPods/CPDAcknowledgements', :branch => 'master'
    pod 'Firebase/Messaging'
    pod 'Eureka', :git => 'https://github.com/xmartlabs/Eureka.git', :branch => 'xcode12'
    pod 'Lokalise', '~> 0.10.0'
    pod 'lottie-ios'
    pod 'MBProgressHUD', '~> 1.2.0'
    pod 'Sentry'
    pod 'SimulatorStatusMagic', :configurations => ['Debug']
    pod 'SwiftGen', '~> 6.3.0'
    pod 'SwiftLint'
    pod 'SwiftMessages', :git => 'https://github.com/SwiftKickMobile/SwiftMessages.git', :branch => 'master'
    pod 'ViewRow', :git => 'https://github.com/EurekaCommunity/ViewRow', :branch => 'master'
    pod 'WhatsNewKit'
    pod 'ZIPFoundation', '~> 0.9'

    target 'HomeAssistantTests' do
        inherit! :search_paths
        shared_tests
    end
end

target 'Shared-iOS' do
    ios_shared_pods

    target 'SharedTests' do
      shared_tests
    end
end

target 'Shared-watchOS' do
    platform :watchos, '5.0'

    shared_pods
end

target 'APNSAttachmentService' do
    ios_shared_pods
end

target 'NotificationContentExtension' do
    ios_shared_pods

    pod 'MBProgressHUD', '~> 1.2.0'
end

target 'SiriIntents' do
    ios_shared_pods
end

target 'WatchAppExtension' do
    platform :watchos, '5.0'

    shared_pods

    pod 'EMTLoadingIndicator', :git => 'https://github.com/hirokimu/EMTLoadingIndicator', :branch => 'master'
end

target 'TodayWidget' do
    ios_shared_pods
end

target 'WidgetsExtension' do
    ios_shared_pods
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '5.0'
            config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '11.0'
            config.build_settings['EXCLUDED_ARCHS[sdk=watchsimulator*]'] = 'x86_64 arm64'
        end
    end
end
