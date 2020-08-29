import Foundation

#if canImport(CoreMediaIO)
import CoreMediaIO

class HACoreMediaObject {
    let id: CMIOObjectID
    init(id: CMIOObjectID) {
        self.id = id
    }

    func value<T>(for property: HACoreMediaProperty<T>) -> T? {
        let propsize: UInt32 = UInt32(MemoryLayout<T>.size)

        let data = UnsafeMutableRawPointer.allocate(
            byteCount: Int(propsize),
            alignment: MemoryLayout<T>.alignment
        )
        defer {
            data.deallocate()
        }

        let result = withUnsafePointer(to: property.address) { addressPtr -> OSStatus in
            var dataUsed: UInt32 = 0
            return OSStatus(CMIOObjectGetPropertyData(id, addressPtr, 0, nil, propsize, &dataUsed, data))
        }

        if result == OSStatus(kCMIOHardwareNoError) {
            return data.load(as: T.self)
        } else {
            return nil
        }
    }

    func value<ValueType>(for property: HACoreMediaProperty<[ValueType]>) -> [ValueType]? {
        var countBytes: UInt32 = 0
        let countResult = withUnsafePointer(to: property.address) { addressPtr -> OSStatus in
            OSStatus(CMIOObjectGetPropertyDataSize(id, addressPtr, 0, nil, &countBytes))
        }

        guard countResult == OSStatus(kCMIOHardwareNoError), countBytes > 0 else {
            return nil
        }

        let dataCount = Int(countBytes) / MemoryLayout<ValueType>.size
        let data = UnsafeMutableRawPointer.allocate(
            byteCount: dataCount,
            alignment: MemoryLayout<ValueType>.alignment
        )
        defer {
            data.deallocate()
        }

        let getResult = withUnsafePointer(to: property.address) { addressPtr -> OSStatus in
            var dataUsed: UInt32 = 0
            return OSStatus(CMIOObjectGetPropertyData(id, addressPtr, 0, nil, countBytes, &dataUsed, data))
        }

        if getResult == OSStatus(kCMIOHardwareNoError) {
            let buffer = data.bindMemory(to: ValueType.self, capacity: dataCount)
            return Array(UnsafeBufferPointer<ValueType>(start: buffer, count: dataCount))
        } else {
            return nil
        }
    }
}

#endif
