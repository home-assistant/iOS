import Foundation
import HAKit
import Shared
import WebRTC

/// WebRTC client configuration provided by the server, mirroring what the frontend fetches via
/// `camera/webrtc/get_client_config` before opening a peer connection. This is how user-configured
/// STUN/TURN servers (e.g. from go2rtc) reach the client — required for remote connections that
/// can't be established with a direct or STUN-derived path.
struct WebRTCClientConfiguration {
    let iceServers: [RTCIceServer]
    /// Label of a data channel the backend expects the client to open, if any.
    let dataChannelLabel: String?
    /// When true the backend doesn't support trickle ICE, so the offer must already contain all
    /// ICE candidates and gathering has to finish before sending it.
    let getCandidatesUpfront: Bool

    /// Used when `get_client_config` fails; matches the frontend's default STUN servers.
    static let fallback = WebRTCClientConfiguration(
        iceServers: [RTCIceServer(urlStrings: AppConstants.WebRTC.iceServers)],
        dataChannelLabel: nil,
        getCandidatesUpfront: false
    )

    init(iceServers: [RTCIceServer], dataChannelLabel: String?, getCandidatesUpfront: Bool) {
        self.iceServers = iceServers
        self.dataChannelLabel = dataChannelLabel
        self.getCandidatesUpfront = getCandidatesUpfront
    }

    init(data: HAData) {
        var servers: [RTCIceServer] = []
        if let configuration: [String: Any] = try? data.decode("configuration"),
           let iceServers = configuration["iceServers"] as? [[String: Any]] {
            for server in iceServers {
                let urls: [String]
                if let url = server["urls"] as? String {
                    urls = [url]
                } else if let urlList = server["urls"] as? [String] {
                    urls = urlList
                } else {
                    continue
                }
                servers.append(RTCIceServer(
                    urlStrings: urls,
                    username: server["username"] as? String,
                    credential: server["credential"] as? String
                ))
            }
        }
        self.iceServers = servers.isEmpty ? Self.fallback.iceServers : servers
        self.dataChannelLabel = try? data.decode("dataChannel")
        self.getCandidatesUpfront = (try? data.decode("getCandidatesUpfront")) ?? false
    }
}
