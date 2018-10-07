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
    pod 'Alamofire', '4.7.3'
    pod 'AlamofireImage', '3.4.1'
    pod 'AlamofireObjectMapper', '5.1.0'
    pod 'DeviceKit', '1.8'
    pod 'Iconic', :git => 'https://github.com/robbiet480/Iconic.git', :branch => 'swift-4.2'
    pod 'KeychainAccess', '3.1.1'
    pod 'ObjectMapper', '3.3.0'
    pod 'PromiseKit', '6.4.1'
    pod 'RealmSwift', '3.11.0'
end

target 'HomeAssistant' do
  shared_pods

  pod 'AlamofireNetworkActivityIndicator', '2.3.0'
  pod 'ColorPickerRow', :git => 'https://github.com/EurekaCommunity/ColorPickerRow', :branch => 'master'
  pod 'Communicator'
  pod 'CPDAcknowledgements', :git => 'https://github.com/CocoaPods/CPDAcknowledgements', :branch => 'master'
  pod 'Eureka', :git => 'https://github.com/xmartlabs/Eureka.git', :branch => 'master'
  pod 'MBProgressHUD', '1.1.0'
  pod 'SwiftGen', '5.3.0'
  pod 'SwiftLint', '0.27.0'
  pod 'UIColor_Hex_Swift'
  pod 'ViewRow', :git => 'https://github.com/EurekaCommunity/ViewRow', :branch => 'Swift4.2'

  target 'HomeAssistantTests' do
    inherit! :search_paths
  end
end

target 'Shared' do
  shared_pods

  target 'SharedTests' do
    inherit! :search_paths
  end
end


target 'HomeAssistantUITests' do

end

target 'APNSAttachmentService' do
  shared_pods
end

target 'NotificationContentExtension' do
    shared_pods

    pod 'MBProgressHUD', '1.1.0'
end

target 'SiriIntents' do
  pod 'PromiseKit', '6.4.1'
end

target 'WatchAppExtension' do
  platform :watchos, '5.0'

  pod 'Communicator'
  pod 'Iconic', :git => 'https://github.com/robbiet480/Iconic.git', :branch => 'swift-4.2'
  pod 'RealmSwift', '3.11.0'
  pod 'ObjectMapper', '3.3.0'
  pod 'UIColor_Hex_Swift'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            if config.build_settings['SDKROOT'] == 'watchos'
                config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '4.2'
            end
        end
    end
end
