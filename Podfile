# Uncomment this line to define a global platform for your project
platform :ios, '9.0'
# Uncomment this line if you're using Swift
use_frameworks!

target 'HomeAssistant' do
  pod 'AcknowList'
  pod 'Alamofire'
  pod 'AlamofireImage'
  pod 'AlamofireNetworkActivityIndicator'
  pod 'AlamofireObjectMapper'
  pod 'AWSCognito'
  pod 'AWSCore'
  pod 'AWSSNS'
  pod 'Crashlytics'
  pod 'DeviceKit'
  pod 'Eureka', :git => 'https://github.com/xmartlabs/Eureka.git', :branch => 'Swift3'
  pod 'Fabric'
  pod 'FontAwesomeKit/MaterialDesignIcons', :git => 'https://github.com/robbiet480/FontAwesomeKit.git', :branch => 'Material-Design-Icons'
  pod 'IKEventSource', :git => 'https://github.com/robbiet480/EventSource.git', :branch => 'swift3'
  pod 'MBProgressHUD'
  pod 'ObjectMapper'
  pod 'PermissionScope', :git => 'https://github.com/robbiet480/PermissionScope.git', :branch => 'swift3-ios10-usernotifications'
  pod 'PromiseKit'
  pod 'Realm'
  pod 'RealmSwift'
  pod 'SwiftLocation'
  pod 'Whisper', :git => 'https://github.com/hyperoslo/Whisper.git', :branch => 'swift-3'
end

target 'HomeAssistantTests' do

end

target 'HomeAssistantUITests' do

end

target 'NotificationContentExtension' do
  pod 'MBProgressHUD'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = '3.0'
        end
    end
end
