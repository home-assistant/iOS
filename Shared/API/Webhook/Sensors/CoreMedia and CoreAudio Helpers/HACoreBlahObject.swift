import Foundation

class HACoreBlahObject {
    let id: UInt32
    init(id: UInt32) {
        self.id = id
    }

    func value<T>(for property: HACoreBlahProperty<T>) -> T? {
        let propsize: UInt32 = UInt32(MemoryLayout<T>.size)

        let data = UnsafeMutableRawPointer.allocate(
            byteCount: Int(propsize),
            alignment: MemoryLayout<T>.alignment
        )
        defer {
            data.deallocate()
        }

        let result = property.getPropertyData(objectID: id, dataSize: propsize, output: data)

        if result == OSStatus(0) {
            return data.load(as: T.self)
        } else {
            return nil
        }
    }

    func value<ValueType>(for property: HACoreBlahProperty<[ValueType]>) -> [ValueType]? {
        var countBytes: UInt32 = 0
        let countResult = property.getPropertyDataSize(objectID: id, dataSize: &countBytes)

        guard countResult == OSStatus(0), countBytes > 0 else {
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

        let getResult = property.getPropertyData(objectID: id, dataSize: countBytes, output: data)

        if getResult == OSStatus(0) {
            let buffer = data.bindMemory(to: ValueType.self, capacity: dataCount)
            return Array(UnsafeBufferPointer<ValueType>(start: buffer, count: dataCount))
        } else {
            return nil
        }
    }
}
