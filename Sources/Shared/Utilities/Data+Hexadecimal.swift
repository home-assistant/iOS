import Foundation

public extension Data {
    var hexadecimal: String {
        map { String(format: "%02x", $0) }
            .joined()
    }
}
