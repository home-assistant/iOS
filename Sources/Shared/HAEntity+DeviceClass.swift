import Foundation
import HAKit

public extension HAEntity {
    var deviceClass: DeviceClass {
        guard let deviceClassString = attributes.dictionary["device_class"] as? String,
              let deviceClass = DeviceClass(rawValue: deviceClassString) else {
            return .unknown
        }

        return deviceClass
    }
}
