# Uncomment this line to define a global platform for your project
platform :ios, '9.0'
# Uncomment this line if you're using Swift
use_frameworks!

plugin 'cocoapods-acknowledgements'

target 'HomeAssistant' do
  pod 'Alamofire'
  pod 'AlamofireImage'
  pod 'AlamofireNetworkActivityIndicator'
  pod 'AlamofireObjectMapper'
  pod 'CPDAcknowledgements'
  pod 'Crashlytics'
  pod 'DeviceKit'
  pod 'Eureka'
  pod 'Fabric'
  pod 'FontAwesomeKit/MaterialDesignIcons', :git => 'https://github.com/robbiet480/FontAwesomeKit.git', :branch => 'Material-Design-Icons'
  pod 'KeychainAccess'
  pod 'MBProgressHUD'
  pod 'ObjectMapper'
  pod 'PermissionScope', :git => 'https://github.com/robbiet480/PermissionScope.git', :branch => 'swift3-ios10-usernotifications'
  pod 'PromiseKit'
  pod 'Realm'
  pod 'RealmSwift'
  pod 'SwiftGen'
  pod 'SwiftLint'
  pod 'SwiftLocation'
end

target 'HomeAssistantTests' do

end

target 'HomeAssistantUITests' do

end

target 'APNSAttachmentService' do
  pod 'KeychainAccess'
end

target 'MapNotificationContentExtension' do
    pod 'MBProgressHUD'
end


target 'NotificationContentExtension' do
  pod 'KeychainAccess'
  pod 'MBProgressHUD'
end

post_install do |installer|
    swift4Targets = ['Eureka']
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            if swift4Targets.include? target.name
                config.build_settings['SWIFT_VERSION'] = '4.0'
            else
                config.build_settings['SWIFT_VERSION'] = '3.0'
            end
        end
    end
end
