import Foundation

public extension Data {
    var hexadecimal: String {
        map { String(format: "%02x", $0) }
            .joined()
    }

    init?(hexadecimal: String) {
        let length = hexadecimal.count / 2
        var byteArray = [UInt8](repeating: 0, count: length)

        for i in 0 ..< length {
            let startIndex = hexadecimal.index(hexadecimal.startIndex, offsetBy: i * 2)
            let endIndex = hexadecimal.index(startIndex, offsetBy: 2)
            let substring = hexadecimal[startIndex ..< endIndex]

            if let byte = UInt8(substring, radix: 16) {
                byteArray[i] = byte
            } else {
                return nil
            }
        }

        self.init(byteArray)
    }
}

extension String {
    var hexadecimal: Data? {
        Data(hexadecimal: self)
    }
}
