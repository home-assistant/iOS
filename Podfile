# Uncomment this line to define a global platform for your project
platform :ios, '10.0'
# Uncomment this line if you're using Swift
use_frameworks!

plugin 'cocoapods-acknowledgements'

def shared_pods
    pod 'Alamofire', '4.7.3'
    pod 'AlamofireImage', '3.4.1'
    pod 'AlamofireObjectMapper', '5.1.0'
    pod 'Crashlytics', '3.10.2'
    pod 'DeviceKit', '1.8'
    pod 'FontAwesomeKit/MaterialDesignIcons', :git => 'https://github.com/robbiet480/FontAwesomeKit.git', :branch => 'Material-Design-Icons'
    pod 'KeychainAccess', '3.1.1'
    pod 'ObjectMapper', '3.3.0'
    pod 'PromiseKit', '6.3.0'
    pod 'RealmSwift'
end

target 'HomeAssistant' do
  shared_pods

  pod 'AlamofireNetworkActivityIndicator', '2.3.0'
  pod 'ColorPickerRow', :git => 'https://github.com/EurekaCommunity/ColorPickerRow', :branch => 'Swift4.2'
  pod 'CPDAcknowledgements', '1.0.0'
  pod 'Eureka', :git => 'https://github.com/xmartlabs/Eureka.git', :branch => 'master'
  pod 'Fabric', '1.7.7'
  pod 'MBProgressHUD', '1.1.0'
  pod 'SwiftGen', '5.3.0'
  pod 'SwiftLint', '0.25.1'
  pod 'UIColor_Hex_Swift'
  pod 'ViewRow', :git => 'https://github.com/EurekaCommunity/ViewRow'

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

target 'MapNotificationContentExtension' do
  pod 'MBProgressHUD', '1.1.0'
  pod 'RealmSwift'
end


target 'NotificationContentExtension' do
    shared_pods

    pod 'MBProgressHUD', '1.1.0'
end

target 'SiriIntents' do
  pod 'PromiseKit', '6.3.0'
end
