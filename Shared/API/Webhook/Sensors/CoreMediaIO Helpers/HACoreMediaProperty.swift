import Foundation

#if canImport(CoreMediaIO)
import CoreMediaIO

struct HACoreMediaProperty<Type> {
    let address: CMIOObjectPropertyAddress

    public init(
        mSelector: CMIOObjectPropertySelector,
        mScope: CMIOObjectPropertyScope,
        mElement: CMIOObjectPropertyElement
    ) {
        self.address = .init(mSelector: mSelector, mScope: mScope, mElement: mElement)
    }
}

extension HACoreMediaProperty {
    static var deviceUID: HACoreMediaProperty<Unmanaged<CFString>> {
        /*
         A CFString that contains a persistent identifier for the CMIODevice. A CMIODevice's UID is persistent across
         boots. The content of the UID string is a black box and may contain information that is unique to a particular
         instance of a CMIODevice's hardware or unique to the CPU. Therefore they are not suitable for passing between
         CPUs or for identifying similar models of hardware. The caller is between CPUs or for identifying similar
         models of hardware. The caller is responsible for releasing the returned CFObject.
         */
        .init(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceUID),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster)
        )
    }

    static var allDevices: HACoreMediaProperty<[CMIODeviceID]> {
        /*
         An array of the CMIODeviceIDs that represent all the devices currently available to the system.
         */
        .init(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster)
        )
    }

    static var name: HACoreMediaProperty<Unmanaged<CFString>> {
        /*
         A CFString that contains the human readable name of the object. The caller is responsible for releasing the
         returned CFObject.
         */
        .init(
            mSelector: CMIOObjectPropertySelector(kCMIOObjectPropertyName),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster)
        )
    }

    static var manufacturer: HACoreMediaProperty<Unmanaged<CFString>> {
        /*
         A CFString that contains the human readable name of the manufacturer of the hardware the CMIOObject is a
         part of. The caller is responsible for releasing the
         returned CFObject.
         */
        .init(
            mSelector: CMIOObjectPropertySelector(kCMIOObjectPropertyManufacturer),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster)
        )
    }

    static var isRunningSomewhere: HACoreMediaProperty<Int32> {
        /*
         A UInt32 where 1 means that the CMIODevice is running in at least one process on the system and 0 means
         that it isn't running at all.
         */
        .init(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
        )
    }
}

#endif
