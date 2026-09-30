import Foundation
import HAKit
import WebRTC

enum WebRTCSignalingCandidate {
    static func remoteCandidate(from data: HAData) -> RTCIceCandidate? {
        guard let candidateDict: [String: Any] = try? data.decode("candidate"),
              let candidateStr = candidateDict["candidate"] as? String,
              !candidateStr.isEmpty else {
            // An empty/null candidate signals end-of-candidates; nothing to add.
            return nil
        }
        // JSON numbers arrive bridged, so read the index through NSNumber rather than casting
        // straight to Int32 — a failed cast would silently file a video candidate under the audio
        // m-line. When the backend sends neither field the frontend defaults `sdpMid` to "0",
        // because a candidate needs one of the two to be accepted at all.
        let sdpMLineIndex = (candidateDict["sdpMLineIndex"] as? NSNumber)?.int32Value ?? 0
        let sdpMidFallback: String? = candidateDict["sdpMLineIndex"] == nil ? "0" : nil
        let sdpMid = candidateDict["sdpMid"] as? String ?? sdpMidFallback
        return RTCIceCandidate(
            sdp: candidateStr,
            sdpMLineIndex: sdpMLineIndex,
            sdpMid: sdpMid
        )
    }

    static func payload(for candidate: RTCIceCandidate) -> [String: Any] {
        [
            "candidate": candidate.sdp,
            "sdpMid": candidate.sdpMid ?? "0",
            "sdpMLineIndex": candidate.sdpMLineIndex,
        ]
    }
}
