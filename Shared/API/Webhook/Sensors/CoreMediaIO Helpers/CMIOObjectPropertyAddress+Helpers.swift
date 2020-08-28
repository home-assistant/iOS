import Foundation

#if canImport(CoreMediaIO)
import CoreMediaIO

extension CMIOObjectPropertyAddress {
    static var deviceID: CMIOObjectPropertyAddress {
        .init(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceUID),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster)
        )
    }

    static var allCameras: CMIOObjectPropertyAddress {
        .init(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster)
        )
    }

    static var cameraName: CMIOObjectPropertyAddress {
        .init(
            mSelector: CMIOObjectPropertySelector(kCMIOObjectPropertyName),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster)
        )
    }

    static var cameraManufacturer: CMIOObjectPropertyAddress {
        .init(
            mSelector: CMIOObjectPropertySelector(kCMIOObjectPropertyManufacturer),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster)
        )
    }

    static var cameraIsOn: CMIOObjectPropertyAddress {
        .init(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
        )
    }
}

#endif
