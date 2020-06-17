import Foundation
import ObjectMapper

public struct StreamCameraResponse: Mappable {
    public init?(map: Map) {}
    public init(fallbackEntityID: String) {
        mjpegPath = "/camera_proxy_stream/\(fallbackEntityID)"
    }

    public var hlsPath: String?
    public var mjpegPath: String?

    public mutating func mapping(map: Map) {
        hlsPath <- map["hls_path"]
        mjpegPath <- map["mjpeg_path"]
    }
}
