import Foundation
import HAKit
import Shared
import WebRTC

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
    enum Constants: String {
        case offer = "camera/webrtc/offer"
        case cadidate = "camera/webrtc/candidate"
    }

    var webRTCClient: WebRTCClient?
    private var sessionId: String?
    private var pendingCandidates: [RTCIceCandidate] = []
    private let server: Server
    private let cameraEntityId: String

    @Published var failureReason: String?
    @Published var showLoader: Bool = true
    @Published var controlsVisible: Bool = true
    @Published var isMuted: Bool = true

    var hideControlsWorkItem: DispatchWorkItem?

    init(server: Server, cameraEntityId: String) {
        self.server = server
        self.cameraEntityId = cameraEntityId
    }

    // MARK: - UI

    func showControlsTemporarily() {
        controlsVisible = true
        hideControlsWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.controlsVisible = false
        }
        hideControlsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
    }

    func toggleMute() {
        guard let webRTCClient else { return }
        if webRTCClient.isAudioMuted() {
            webRTCClient.unmuteAudio()
        } else {
            webRTCClient.muteAudio()
        }
        // Always get the final state from the client to ensure consistency
        isMuted = webRTCClient.isAudioMuted()
    }

    // MARK: - WebRTC

    func start() {
        webRTCClient = nil
        webRTCClient = WebRTCClient(iceServers: AppConstants.WebRTC.iceServers)
        guard let webRTCClient else {
            assertionFailure("WebRTCClient initialization failed")
            return
        }
        webRTCClient.delegate = self
        webRTCClient.offer { [weak self] sdp in
            guard let self else {
                assertionFailure("Self is nil in WebRTCViewPlayerViewModel.start")
                return
            }
            guard let api = Current.api(for: server) else {
                assertionFailure("API for server is nil")
                return
            }

            api.connection.subscribe(to: .init(type: .webSocket(Constants.offer.rawValue), data: [
                "entity_id": cameraEntityId,
                "offer": sdp.sdp,
            ])) { [weak self] result in
                switch result {
                case let .success(data):
                    Current.Log.verbose("WebRTC offer sent successfully: \(data)")
                case let .failure(error):
                    Current.Log.error("Failed to send WebRTC offer: \(error.localizedDescription)")
                    self?.showLoader = false
                    self?.failureReason = error.localizedDescription
                }
            } handler: { [weak self] _, data in
                guard let self else { return }
                guard let typeString: String = try? data.decode("type") else {
                    assertionFailure("Failed to decode type from data")
                    return
                }
                let type = WebRTCSignalType(typeString)
                switch type {
                case .session:
                    handleSession(data)
                case .answer:
                    handleAnswer(data)
                case .candidate:
                    handleCandidate(data)
                case .unknown:
                    debugPrint("Unknown type: \(typeString)")
                }
            }
        }
    }

    private func handleSession(_ data: HAData) {
        guard let sessionId: String = try? data.decode("session_id") else {
            assertionFailure("Failed to decode session_id from data")
            return
        }
        self.sessionId = sessionId
        for candidate in pendingCandidates {
            sendCandidate(candidate)
        }
        pendingCandidates.removeAll()
    }

    private func handleAnswer(_ data: HAData) {
        guard let answerSDP: String = try? data.decode("answer") else {
            assertionFailure("Failed to decode answer from data")
            return
        }
        let sdp = RTCSessionDescription(type: .answer, sdp: answerSDP)
        webRTCClient?.set(remoteSdp: sdp) { error in
            if let error {
                Current.Log.error("Failed to set remote SDP: \(error.localizedDescription)")
            }
        }
    }

    private func handleCandidate(_ data: HAData) {
        guard let candidateDict: [String: Any] = try? data.decode("candidate") else {
            assertionFailure("Failed to decode candidate from data")
            return
        }
        guard let candidateStr = candidateDict["candidate"] as? String else {
            assertionFailure("Missing candidate string in candidateDict")
            return
        }
        let sdpMLineIndex = candidateDict["sdpMLineIndex"] as? Int32 ?? 0
        let sdpMid = candidateDict["sdpMid"] as? String
        let candidate = RTCIceCandidate(
            sdp: candidateStr,
            sdpMLineIndex: sdpMLineIndex,
            sdpMid: sdpMid
        )
        webRTCClient?.set(remoteCandidate: candidate) { error in
            if let error {
                print("Failed to add remote candidate: \(error)")
            }
        }
    }

    private func sendCandidate(_ candidate: RTCIceCandidate) {
        guard let sessionId else {
            // No session yet, store for later
            pendingCandidates.append(candidate)
            return
        }
        guard let api = Current.api(for: server) else {
            assertionFailure("API for server is nil")
            return
        }
        // Send candidate to backend
        api.connection.send(.init(type: .webSocket(Constants.cadidate.rawValue), data: [
            "entity_id": cameraEntityId,
            "session_id": sessionId,
            "candidate": [
                "candidate": candidate.sdp,
                "sdpMid": candidate.sdpMid ?? "0",
                "sdpMLineIndex": candidate.sdpMLineIndex,
            ],
        ])).promise.pipe { result in
            switch result {
            case let .fulfilled(data):
                Current.Log.verbose("Sent candidate: \(data)")
            case let .rejected(error):
                Current.Log.error("Failed to send candidate: \(error.localizedDescription)")
            }
        }
    }
}

extension WebRTCViewPlayerViewModel: WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        sendCandidate(candidate)
    }

    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        debugPrint(state)
        Current.Log.info("WebRTC connection state changed to: \(state)")
    }

    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        Current.Log.info("WebRTC client received data of size: \(data.count) bytes")
    }
}
