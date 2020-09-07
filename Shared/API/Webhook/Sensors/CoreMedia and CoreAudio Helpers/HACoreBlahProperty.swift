import Foundation

#if canImport(CoreMediaIO)
import CoreMediaIO
#endif
#if targetEnvironment(macCatalyst)
import CoreAudio
#endif

struct HACoreBlahProperty<Type> {
    enum AddressType {
        #if canImport(CoreMediaIO)
        case coreMedia(CMIOObjectPropertyAddress)
        #endif
        #if targetEnvironment(macCatalyst)
        case coreAudio(AudioObjectPropertyAddress)
        #endif
    }

    let address: AddressType

    #if canImport(CoreMediaIO)
    public init(
        forCoreMedia: (),
        mSelector: CMIOObjectPropertySelector,
        mScope: CMIOObjectPropertyScope,
        mElement: CMIOObjectPropertyElement
    ) {
        self.address = .coreMedia(.init(mSelector: mSelector, mScope: mScope, mElement: mElement))
    }
    #endif

    #if targetEnvironment(macCatalyst)
    public init(
        forCoreAudio: (),
        mSelector: AudioObjectPropertySelector,
        mScope: AudioObjectPropertyScope,
        mElement: AudioObjectPropertyElement
    ) {
        self.address = .coreAudio(.init(mSelector: mSelector, mScope: mScope, mElement: mElement))
    }
    #endif

    public func addListener(
        objectID: UInt32,
        handler: @escaping () -> Void
    ) -> OSStatus {
        switch address {
        #if canImport(CoreMediaIO)
        case .coreMedia(let address):
            return withUnsafePointer(to: address) { addressPtr in
                CMIOObjectAddPropertyListenerBlock(objectID, addressPtr, .main) { _, _ in
                    handler()
                }
            }
        #endif
        #if targetEnvironment(macCatalyst)
        case .coreAudio(let address):
            return withUnsafePointer(to: address) { addressPtr in
                AudioObjectAddPropertyListenerBlock(objectID, addressPtr, .main) { _, _ in
                    handler()
                }
            }
        #endif
        }
    }

    public func getPropertyDataSize(
        objectID: UInt32,
        dataSize: UnsafeMutablePointer<UInt32>
    ) -> OSStatus {
        switch address {
        #if canImport(CoreMediaIO)
        case .coreMedia(let address):
            return withUnsafePointer(to: address) { addressPtr -> OSStatus in
                OSStatus(CMIOObjectGetPropertyDataSize(objectID, addressPtr, 0, nil, dataSize))
            }
        #endif
        #if targetEnvironment(macCatalyst)
        case .coreAudio(let address):
            return withUnsafePointer(to: address) { addressPtr -> OSStatus in
                OSStatus(AudioObjectGetPropertyDataSize(objectID, addressPtr, 0, nil, dataSize))
            }
        #endif
        }
    }

    public func getPropertyData(
        objectID: UInt32,
        dataSize: UInt32,
        output: UnsafeMutableRawPointer
    ) -> OSStatus {
        switch address {
        #if canImport(CoreMediaIO)
        case .coreMedia(let address):
            return withUnsafePointer(to: address) { addressPtr in
                var dataUsed: UInt32 = 0
                return OSStatus(CMIOObjectGetPropertyData(objectID, addressPtr, 0, nil, dataSize, &dataUsed, output))
            }
        #endif
        #if targetEnvironment(macCatalyst)
        case .coreAudio(let address):
            return withUnsafePointer(to: address) { addressPtr in
                var dataSizePtr = dataSize
                return OSStatus(AudioObjectGetPropertyData(objectID, addressPtr, 0, nil, &dataSizePtr, output))
            }
        #endif
        }
    }
}

#if canImport(CoreMediaIO)
extension HACoreBlahProperty {
    static var cmDeviceUID: HACoreBlahProperty<Unmanaged<CFString>> {
        /*
         A CFString that contains a persistent identifier for the CMIODevice. A CMIODevice's UID is persistent across
         boots. The content of the UID string is a black box and may contain information that is unique to a particular
         instance of a CMIODevice's hardware or unique to the CPU. Therefore they are not suitable for passing between
         CPUs or for identifying similar models of hardware. The caller is between CPUs or for identifying similar
         models of hardware. The caller is responsible for releasing the returned CFObject.
         */
        .init(
            forCoreMedia: (),
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceUID),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster)
        )
    }

    static var cmAllDevices: HACoreBlahProperty<[CMIODeviceID]> {
        /*
         An array of the CMIODeviceIDs that represent all the devices currently available to the system.
         */
        .init(
            forCoreMedia: (),
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster)
        )
    }
    static var cmName: HACoreBlahProperty<Unmanaged<CFString>> {
        /*
         A CFString that contains the human readable name of the object. The caller is responsible for releasing the
         returned CFObject.
         */
        .init(
            forCoreMedia: (),
            mSelector: CMIOObjectPropertySelector(kCMIOObjectPropertyName),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster)
        )
    }

    static var cmManufacturer: HACoreBlahProperty<Unmanaged<CFString>> {
        /*
         A CFString that contains the human readable name of the manufacturer of the hardware the CMIOObject is a
         part of. The caller is responsible for releasing the
         returned CFObject.
         */
        .init(
            forCoreMedia: (),
            mSelector: CMIOObjectPropertySelector(kCMIOObjectPropertyManufacturer),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster)
        )
    }

    static var cmIsRunningSomewhere: HACoreBlahProperty<UInt32> {
        /*
         A UInt32 where 1 means that the CMIODevice is running in at least one process on the system and 0 means
         that it isn't running at all.
         */
        .init(
            forCoreMedia: (),
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
        )
    }
}
#endif

#if targetEnvironment(macCatalyst)
extension HACoreBlahProperty {
    static var caDeviceUID: HACoreBlahProperty<Unmanaged<CFString>> {
        /*
         A CFString that contains a persistent identifier for the AudioDevice. An AudioDevice's UID is persistent across
         boots. The content of the UID string is a black box and may contain information that is unique to a particular
         instance of an AudioDevice's hardware or unique to the CPU. Therefore they are not suitable for passing between
         CPUs or for identifying similar models of hardware. The caller is responsible for releasing the returned
         CFObject.
         */
        .init(
            forCoreAudio: (),
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyDeviceUID),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
        )
    }

    static var caAllDevices: HACoreBlahProperty<[AudioDeviceID]> {
        /*
         An array of the AudioObjectIDs that represent all the devices currently available to the system.
         */
        .init(
            forCoreAudio: (),
            mSelector: AudioObjectPropertySelector(kAudioHardwarePropertyDevices),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
        )
    }

    static var caName: HACoreBlahProperty<Unmanaged<CFString>> {
        /*
         A CFString that contains the human readable name of the object. The caller is responsible for releasing the
         returned CFObject.
         */
        .init(
            forCoreAudio: (),
            mSelector: AudioObjectPropertySelector(kAudioObjectPropertyName),
            mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeInput),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
        )
    }

    static var caManufacturer: HACoreBlahProperty<Unmanaged<CFString>> {
        /*
         A CFString that contains the human readable name of the manufacturer of the hardware the AudioObject is a
         part of. The caller is responsible for releasing the returned CFObject.
         */
        .init(
            forCoreAudio: (),
            mSelector: AudioObjectPropertySelector(kAudioObjectPropertyManufacturer),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
        )
    }

    static var caIsRunningSomewhere: HACoreBlahProperty<UInt32> {
        /*
         A UInt32 where 1 means that the AudioDevice is running in at least one process on the system and 0 means that
         it isn't running at all.
         */
        .init(
            forCoreAudio: (),
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyDeviceIsRunningSomewhere),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
        )
    }

    static var caInputStreams: HACoreBlahProperty<[AudioStreamID]> {
        /*
         An array of AudioStreamIDs that represent the AudioStreams of the AudioDevice. Note that if a notification is
         received for this property, any cached AudioStreamIDs for the device become invalid and need to be re-fetched.
         */
        .init(
            forCoreAudio: (),
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyStreams),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeInput),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
        )
    }

    static var caOutputStreams: HACoreBlahProperty<[AudioStreamID]> {
        /*
         An array of AudioStreamIDs that represent the AudioStreams of the AudioDevice. Note that if a notification is
         received for this property, any cached AudioStreamIDs for the device become invalid and need to be re-fetched.
         */
        .init(
            forCoreAudio: (),
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyStreams),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeOutput),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
        )
    }
}
#endif
