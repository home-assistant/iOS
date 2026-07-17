import AVFoundation
import Foundation
import HAKit
import HAKit_PromiseKit
import Shared
import SwiftUI
import WebRTC

private enum CameraEntityFeature {
    static let twoWayAudio = 4
}

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
    private let supportsTalkback: Bool
    private var statesToken: HACancellable?

    var onClientReady: (() -> Void)?

    @Published var failureReason: String?
    @Published var showLoader: Bool = true
    @Published var isMuted: Bool = true
    @Published var isWebRTCUnsupported: Bool = false
    @Published var isTalking: Bool = false
    @Published var isTalkbackSupported: Bool = false

    /// Invoked on offer rejection or ICE failure. Used by the notification extension to fall back;
    /// the SwiftUI player leaves it `nil` and observes the published properties instead.
    var onFailure: (() -> Void)?

    init(server: Server, cameraEntityId: String, supportsTalkback: Bool = false) {
        self.server = server
        self.cameraEntityId = cameraEntityId
        self.supportsTalkback = supportsTalkback
    }

    deinit {
        statesToken?.cancel()
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
        guard supportsTalkback else {
            connect(withTalkback: false)
            return
        }
        determineTalkbackSupport { [weak self] supported in
            self?.connect(withTalkback: supported)
        }
    }

    private func connect(withTalkback: Bool) {
        webRTCClient?.closeConnection()
        sessionId = nil
        pendingCandidates.removeAll()
        webRTCClient = WebRTCClient(
            iceServers: AppConstants.WebRTC.iceServers,
            supportsTalkback: withTalkback
        )
        guard let webRTCClient else {
            assertionFailure("WebRTCClient initialization failed")
            return
        }
        webRTCClient.delegate = self
        onClientReady?()
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
                    // Check if the error indicates WebRTC is not supported
                    if error.localizedDescription.contains("does not support WebRTC") ||
                        error.localizedDescription.contains("frontend_stream_types") {
                        self?.isWebRTCUnsupported = true
                    }
                    self?.onFailure?()
                }
            } handler: { [weak self] _, data in
                self?.handleSignal(data)
            }
        }
    }

    private func handleSignal(_ data: HAData) {
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

    // MARK: - Talkback

    func toggleTalkback() {
        if isTalking {
            stopTalkback()
        } else {
            startTalkback()
        }
    }

    private func startTalkback() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let granted = await self.requestMicrophonePermission()
            guard granted else {
                self.failureReason = L10n.CameraPlayer.Talkback.microphoneDenied
                return
            }
            self.webRTCClient?.setMicrophoneEnabled(true)
            self.isTalking = true
        }
    }

    private func stopTalkback() {
        webRTCClient?.setMicrophoneEnabled(false)
        isTalking = false
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func determineTalkbackSupport(completion: @escaping (Bool) -> Void) {
        guard let api = Current.api(for: server) else {
            completion(false)
            return
        }
        var finished = false
        let finish: (Bool) -> Void = { [weak self] supported in
            Task { @MainActor [weak self] in
                guard !finished else { return }
                finished = true
                self?.statesToken?.cancel()
                self?.statesToken = nil
                self?.isTalkbackSupported = supported
                completion(supported)
            }
        }
        statesToken = api.connection.caches.states().subscribe { [weak self] token, states in
            guard let self else {
                token.cancel()
                return
            }
            guard let entity = states[cameraEntityId] else { return }
            let features = (entity.attributes["supported_features"] as? Int) ?? 0
            finish((features & CameraEntityFeature.twoWayAudio) != 0)
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            finish(false)
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
        if state == .failed {
            onFailure?()
        }
    }

    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        Current.Log.info("WebRTC client received data of size: \(data.count) bytes")
    }
}
