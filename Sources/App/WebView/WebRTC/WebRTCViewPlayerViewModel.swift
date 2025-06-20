import Foundation
import WebRTC
import Shared
import HAKit

enum WebRTCSignalType: String {
    case session
    case answer
    case candidate
    case unknown

    init(_ raw: String) {
        self = WebRTCSignalType(rawValue: raw) ?? .unknown
    }
}

final class WebRTCViewPlayerViewModel: ObservableObject {
    var webRTCClient: WebRTCClient!
    private var sessionId: String?
    private var pendingCandidates: [RTCIceCandidate] = []

    // swiftlint:disable force_try
    func start() {
        webRTCClient = WebRTCClient(iceServers: [
            "stun:stun.home-assistant.io:80",
            "stun:stun.home-assistant.io:3478"
        ])
        webRTCClient.delegate = self
        webRTCClient.offer { sdp in
            Current.api(for: Current.servers.all.first!)!.connection.subscribe(to: .init(type: .webSocket("camera/webrtc/offer"), data: [
                "entity_id": "camera.bruno_s_office_high",
                "offer": sdp.sdp
            ]), handler: { [weak self] _, data in
                guard let self = self else { return }
                let type = WebRTCSignalType(try! data.decode("type"))
                switch type {
                case .session:
                    self.handleSession(data)
                case .answer:
                    self.handleAnswer(data)
                case .candidate:
                    self.handleCandidate(data)
                case .unknown:
                    print("Unknown type: \(try! data.decode("type"))")
                }
            })
        }
    }

    private func handleSession(_ data: HAData) {
        self.sessionId = try! data.decode("session_id")
        for candidate in self.pendingCandidates {
            self.sendCandidate(candidate)
        }
        self.pendingCandidates.removeAll()
    }

    private func handleAnswer(_ data: HAData) {
        let answerSDP: String = try! data.decode("answer")
        let sdp = RTCSessionDescription(type: .answer, sdp: answerSDP)
        self.webRTCClient.set(remoteSdp: sdp) { error in
            if let error = error {
                print("Failed to set remote SDP: \(error)")
            }
        }
    }

    // swiftlint:disable force_cast
    private func handleCandidate(_ data: HAData) {
        let candidateDict: [String: Any] = try! data.decode("candidate")
        let candidate = RTCIceCandidate(
            sdp: candidateDict["candidate"] as! String,
            sdpMLineIndex: candidateDict["sdpMLineIndex"] as? Int32 ?? 0,
            sdpMid: candidateDict["sdpMid"] as? String
        )
        self.webRTCClient.set(remoteCandidate: candidate) { error in
            if let error = error {
                print("Failed to add remote candidate: \(error)")
            }
        }
    }

    private func sendCandidate(_ candidate: RTCIceCandidate) {
        guard let sessionId = sessionId else {
            // No session yet, store for later
            pendingCandidates.append(candidate)
            return
        }
        // Send candidate to backend
        Current.api(for: Current.servers.all.first!)!.connection.send(.init(type: .webSocket("camera/webrtc/candidate"), data: [
            "entity_id": "camera.bruno_s_office_high",
            "session_id": sessionId,
            "candidate": [
                "candidate": candidate.sdp,
                "sdpMid": candidate.sdpMid ?? "0",
                "sdpMLineIndex": candidate.sdpMLineIndex
            ]
        ]))
    }
}

extension WebRTCViewPlayerViewModel: WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        sendCandidate(candidate)
    }

    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        print(state)
    }

    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        print(data)
    }
}
