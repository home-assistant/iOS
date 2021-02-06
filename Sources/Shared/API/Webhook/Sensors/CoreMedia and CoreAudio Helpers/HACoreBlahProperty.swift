import Foundation

#if canImport(CoreMediaIO)
import CoreMediaIO
#endif
#if targetEnvironment(macCatalyst)
import CoreAudio
#endif

public protocol HACoreBlahProperty {
    associatedtype ValueType
    func addListener(objectID: UInt32, handler: @escaping () -> Void) -> OSStatus
    func getPropertyDataSize(objectID: UInt32, dataSize: UnsafeMutablePointer<UInt32>) -> OSStatus
    func getPropertyData(objectID: UInt32, dataSize: UInt32, output: UnsafeMutableRawPointer) -> OSStatus
}

#if canImport(CoreMediaIO)
public struct HACoreMediaProperty<Type>: HACoreBlahProperty {
    public typealias ValueType = Type
    public let address: CMIOObjectPropertyAddress
    public init(
        mSelector: CMIOObjectPropertySelector,
        mScope: CMIOObjectPropertyScope,
        mElement: CMIOObjectPropertyElement
    ) {
        self.address = .init(mSelector: mSelector, mScope: mScope, mElement: mElement)
    }

    public func addListener(objectID: UInt32, handler: @escaping () -> Void) -> OSStatus {
        withUnsafePointer(to: address) { addressPtr in
            CMIOObjectAddPropertyListenerBlock(objectID, addressPtr, .main) { _, _ in
                handler()
            }
        }
    }

    public func getPropertyDataSize(objectID: UInt32, dataSize: UnsafeMutablePointer<UInt32>) -> OSStatus {
        withUnsafePointer(to: address) { addressPtr -> OSStatus in
            OSStatus(CMIOObjectGetPropertyDataSize(objectID, addressPtr, 0, nil, dataSize))
        }
    }

    public func getPropertyData(objectID: UInt32, dataSize: UInt32, output: UnsafeMutableRawPointer) -> OSStatus {
        withUnsafePointer(to: address) { addressPtr in
            var dataUsed: UInt32 = 0
            return OSStatus(CMIOObjectGetPropertyData(objectID, addressPtr, 0, nil, dataSize, &dataUsed, output))
        }
    }
}
#endif

#if targetEnvironment(macCatalyst)
public struct HACoreAudioProperty<Type>: HACoreBlahProperty {
    public typealias ValueType = Type
    public let address: AudioObjectPropertyAddress
    public init(
        mSelector: AudioObjectPropertySelector,
        mScope: AudioObjectPropertyScope,
        mElement: AudioObjectPropertyElement
    ) {
        self.address = .init(mSelector: mSelector, mScope: mScope, mElement: mElement)
    }

    public func addListener(objectID: UInt32, handler: @escaping () -> Void) -> OSStatus {
        withUnsafePointer(to: address) { addressPtr in
            AudioObjectAddPropertyListenerBlock(objectID, addressPtr, .main) { _, _ in
                handler()
            }
        }
    }

    public func getPropertyDataSize(objectID: UInt32, dataSize: UnsafeMutablePointer<UInt32>) -> OSStatus {
        withUnsafePointer(to: address) { addressPtr -> OSStatus in
            OSStatus(AudioObjectGetPropertyDataSize(objectID, addressPtr, 0, nil, dataSize))
        }
    }

    public func getPropertyData(objectID: UInt32, dataSize: UInt32, output: UnsafeMutableRawPointer) -> OSStatus {
        withUnsafePointer(to: address) { addressPtr in
            var dataSizePtr = dataSize
            return OSStatus(AudioObjectGetPropertyData(objectID, addressPtr, 0, nil, &dataSizePtr, output))
        }
    }
}
#endif

#if canImport(CoreMediaIO)
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

    static var isRunningSomewhere: HACoreMediaProperty<UInt32> {
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

#if targetEnvironment(macCatalyst)
extension HACoreAudioProperty {
    static var deviceUID: HACoreAudioProperty<Unmanaged<CFString>> {
        /*
         A CFString that contains a persistent identifier for the AudioDevice. An AudioDevice's UID is persistent across
         boots. The content of the UID string is a black box and may contain information that is unique to a particular
         instance of an AudioDevice's hardware or unique to the CPU. Therefore they are not suitable for passing between
         CPUs or for identifying similar models of hardware. The caller is responsible for releasing the returned
         CFObject.
         */
        .init(
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyDeviceUID),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
        )
    }

    static var allDevices: HACoreAudioProperty<[AudioDeviceID]> {
        /*
         An array of the AudioObjectIDs that represent all the devices currently available to the system.
         */
        .init(
            mSelector: AudioObjectPropertySelector(kAudioHardwarePropertyDevices),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
        )
    }

    static var name: HACoreAudioProperty<Unmanaged<CFString>> {
        /*
         A CFString that contains the human readable name of the object. The caller is responsible for releasing the
         returned CFObject.
         */
        .init(
            mSelector: AudioObjectPropertySelector(kAudioObjectPropertyName),
            mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeInput),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
        )
    }

    static var manufacturer: HACoreAudioProperty<Unmanaged<CFString>> {
        /*
         A CFString that contains the human readable name of the manufacturer of the hardware the AudioObject is a
         part of. The caller is responsible for releasing the returned CFObject.
         */
        .init(
            mSelector: AudioObjectPropertySelector(kAudioObjectPropertyManufacturer),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
        )
    }

    static var isRunningSomewhere: HACoreAudioProperty<UInt32> {
        /*
         A UInt32 where 1 means that the AudioDevice is running in at least one process on the system and 0 means that
         it isn't running at all.
         */
        .init(
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyDeviceIsRunningSomewhere),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
        )
    }

    static var inputStreams: HACoreAudioProperty<[AudioStreamID]> {
        /*
         An array of AudioStreamIDs that represent the AudioStreams of the AudioDevice. Note that if a notification is
         received for this property, any cached AudioStreamIDs for the device become invalid and need to be re-fetched.
         */
        .init(
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyStreams),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeInput),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
        )
    }

    static var outputStreams: HACoreAudioProperty<[AudioStreamID]> {
        /*
         An array of AudioStreamIDs that represent the AudioStreams of the AudioDevice. Note that if a notification is
         received for this property, any cached AudioStreamIDs for the device become invalid and need to be re-fetched.
         */
        .init(
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyStreams),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeOutput),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
        )
    }
}
#endif
