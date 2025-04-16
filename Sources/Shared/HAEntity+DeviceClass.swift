import Foundation
import HAKit

public extension HAEntity {
    enum DeviceClass: String {
        case garage
        case gate
        case door
        case damper
        case shutter
        case curtain
        case blind
        case shade
        case restart
        case update
        case outlet
        case `switch`
        case unknown
    }

    var deviceClass: DeviceClass {
        guard let deviceClassString = attributes.dictionary["device_class"] as? String,
              let deviceClass = DeviceClass(rawValue: deviceClassString) else {
            return .unknown
        }

        return deviceClass
    }
}
