import Foundation

/// The first byte of every decrypted binary message.
enum SendspinBinaryType {
    static let json: UInt8 = 0
    static let fragment: UInt8 = 1
    static let audioChunk: UInt8 = 4
}
