import Foundation

/// The `player@v1_support` object of `client/hello`.
struct SendspinPlayerSupport: Codable, Equatable {
    let supportedFormats: [SendspinAudioFormat]
    let bufferCapacity: Int

    enum CodingKeys: String, CodingKey {
        case supportedFormats = "supported_formats"
        case bufferCapacity = "buffer_capacity"
    }
}
