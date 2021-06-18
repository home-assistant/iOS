import Foundation
import ObjectMapper

public struct StreamCameraResponse: Mappable {
    public init?(map: Map) {
        if map.JSON["hls_path"] == nil, map.JSON["mjpeg_path"] == nil {
            // an error masquerading as a 200
            Current.Log.info("stream camera response wasn't available")
            return nil
        }
    }

    public init(fallbackEntityID: String) {
        self.mjpegPath = "/api/camera_proxy_stream/\(fallbackEntityID)"
    }

    public var hlsPath: String?
    public var mjpegPath: String?

    public mutating func mapping(map: Map) {
        hlsPath <- map["hls_path"]
        mjpegPath <- map["mjpeg_path"]
    }
}
