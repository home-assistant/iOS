import Foundation

class HACoreBlahObject {
    let id: UInt32
    init(id: UInt32) {
        self.id = id
    }

    fileprivate func value<PropertyType: HACoreBlahProperty>(for property: PropertyType) -> PropertyType.ValueType? {
        let propsize = UInt32(MemoryLayout<PropertyType.ValueType>.size)

        let data = UnsafeMutableRawPointer.allocate(
            byteCount: Int(propsize),
            alignment: MemoryLayout<PropertyType.ValueType>.alignment
        )
        defer {
            data.deallocate()
        }

        let result = property.getPropertyData(objectID: id, dataSize: propsize, output: data)

        if result == OSStatus(0) {
            return data.load(as: PropertyType.ValueType.self)
        } else {
            return nil
        }
    }

    fileprivate func value<PropertyType: HACoreBlahProperty, ElementType>(
        for property: PropertyType
    ) -> [ElementType]? where PropertyType.ValueType == [ElementType] {
        var countBytes: UInt32 = 0
        let countResult = property.getPropertyDataSize(objectID: id, dataSize: &countBytes)

        guard countResult == OSStatus(0), countBytes > 0 else {
            return nil
        }

        let data = UnsafeMutableRawPointer.allocate(
            byteCount: Int(countBytes),
            alignment: MemoryLayout<ElementType>.alignment
        )
        defer {
            data.deallocate()
        }

        let getResult = property.getPropertyData(objectID: id, dataSize: countBytes, output: data)

        if getResult == OSStatus(0) {
            let elementCount = Int(countBytes) / MemoryLayout<ElementType>.size
            let buffer = data.bindMemory(to: ElementType.self, capacity: elementCount)
            return Array(UnsafeBufferPointer<ElementType>(start: buffer, count: elementCount))
        } else {
            return nil
        }
    }
}

#if canImport(CoreMediaIO)
import CoreMediaIO

class HACoreMediaObject: HACoreBlahObject {
    override init(id: CMIOObjectID) {
        super.init(id: id)
    }

    func value<T>(for property: HACoreMediaProperty<T>) -> T? {
        super.value(for: property)
    }

    func value<ValueType>(for property: HACoreMediaProperty<[ValueType]>) -> [ValueType]? {
        super.value(for: property)
    }
}
#endif

#if targetEnvironment(macCatalyst)
import CoreAudio

class HACoreAudioObject: HACoreBlahObject {
    override init(id: AudioObjectID) {
        super.init(id: id)
    }

    func value<T>(for property: HACoreAudioProperty<T>) -> T? {
        super.value(for: property)
    }

    func value<ValueType>(for property: HACoreAudioProperty<[ValueType]>) -> [ValueType]? {
        super.value(for: property)
    }
}
#endif
