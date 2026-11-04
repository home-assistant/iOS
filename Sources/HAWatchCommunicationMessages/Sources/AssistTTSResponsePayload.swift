import Foundation

/// Payload of an `assistTTSResponse` message (phone → watch): where to fetch the synthesized
/// speech for playback. Key names cross the wire — never rename them.
public struct AssistTTSResponsePayload {
    public let mediaURL: URL

    public init(mediaURL: URL) {
        self.mediaURL = mediaURL
    }

    public init?(content: [String: Any]) {
        guard let urlString = content["mediaURL"] as? String,
              let mediaURL = URL(string: urlString) else {
            return nil
        }
        self.mediaURL = mediaURL
    }

    public var content: [String: Any] {
        ["mediaURL": mediaURL.absoluteString]
    }
}
