# Uncomment this line to define a global platform for your project
platform :ios, '10.0'
# Uncomment this line if you're using Swift
use_frameworks!

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
    pod 'Alamofire', '~> 4.8.2'
    pod 'AlamofireImage', '~> 3.5.2'
    pod 'DeviceKit', '~> 2.0'
    pod 'Iconic', :git => 'https://github.com/robbiet480/Iconic.git', :branch => 'swift-4.2'
    pod 'KeychainAccess', '~> 3.2.0'
    pod 'ObjectMapper', :git => 'https://github.com/tristanhimmelman/ObjectMapper.git', :branch => 'master'
    pod 'PromiseKit', '~> 6.8.4'
    pod 'RealmSwift', '~> 3.14.1'
    pod 'Sodium'
    pod 'Starscream'
    pod 'UIColor_Hex_Swift', '~> 5.1.0'
    pod 'Version', :git => 'https://github.com/guykogus/Version.git', :branch => 'master'
    pod 'XCGLogger', '~> 7.0.0'
end

def ios_shared_pods
    shared_pods

    pod 'ReachabilitySwift'
end

target 'HomeAssistant' do
    ios_shared_pods

    pod 'AlamofireNetworkActivityIndicator', '~> 2.3.0'
    pod 'arek/Location', :git => 'https://github.com/liweihan/arek', :branch => 'develop'
    pod 'arek/Motion', :git => 'https://github.com/liweihan/arek', :branch => 'develop'
    pod 'arek/Notifications', :git => 'https://github.com/liweihan/arek', :branch => 'develop'
    pod 'CallbackURLKit'
    pod 'ColorPickerRow', :git => 'https://github.com/EurekaCommunity/ColorPickerRow', :branch => 'master'
    pod 'Communicator'
    pod 'CPDAcknowledgements', :git => 'https://github.com/CocoaPods/CPDAcknowledgements', :branch => 'master'
    pod 'Firebase/Core'
    pod 'Firebase/Messaging'
    pod 'Eureka', :git => 'https://github.com/xmartlabs/Eureka.git', :branch => 'master'
    pod 'Lokalise', '~> 0.10.0'
    pod 'MBProgressHUD', '~> 1.1.0'
    pod 'SwiftGen', '~> 6.1.0'
    pod 'SwiftLint', '~> 0.31.0'
    pod 'ViewRow', :git => 'https://github.com/EurekaCommunity/ViewRow', :branch => 'master'
    pod 'ZIPFoundation', '~> 0.9'

    target 'HomeAssistantTests' do
      inherit! :search_paths
    end
end

target 'Shared-iOS' do
    ios_shared_pods

    pod 'Crashlytics'
    pod 'Fabric'

    target 'SharedTests' do
      inherit! :search_paths
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

    pod 'MBProgressHUD', '~> 1.1.0'
end

target 'SiriIntents' do
    ios_shared_pods
end

target 'WatchAppExtension' do
    platform :watchos, '5.0'

    shared_pods

    pod 'Communicator'
    pod 'EMTLoadingIndicator', '~> 4.0.0'
end

target 'TodayWidget' do
    ios_shared_pods
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            if config.build_settings['SDKROOT'] == 'watchos'
                config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '5.0'
            end
        end
    end
end
