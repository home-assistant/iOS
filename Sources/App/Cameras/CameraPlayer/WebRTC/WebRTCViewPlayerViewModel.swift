import Foundation
import HAKit
import HAKit_PromiseKit
import Shared
import SwiftUI
import WebRTC

enum WebRTCSignalType: String {
    case session
    case answer
    case candidate
    case error
    case unknown

    init(_ raw: String) {
        self = WebRTCSignalType(rawValue: raw) ?? .unknown
    }
}

final class WebRTCViewPlayerViewModel: ObservableObject {
    enum Constants: String {
        case clientConfig = "camera/webrtc/get_client_config"
        case offer = "camera/webrtc/offer"
        case candidate = "camera/webrtc/candidate"
    }

    /// How long to wait for the first rendered frame before giving up so callers can fall back
    /// to HLS instead of showing a spinner forever (e.g. remote connections that need TURN).
    private static let connectionTimeout: TimeInterval = 15

    var webRTCClient: WebRTCClient?
    private var sessionId: String?
    private var pendingCandidates: [RTCIceCandidate] = []
    private var offerSubscription: HACancellable?
    private var timeoutWorkItem: DispatchWorkItem?
    /// Regenerated on every start/teardown so async setup steps (config fetch, offer creation)
    /// from a previous attempt are ignored instead of resurrecting a torn-down connection.
    private var connectionToken = UUID()
    private weak var renderer: RTCVideoRenderer?
    private let server: Server
    private let cameraEntityId: String
    private let supportsTalkback: Bool

    @Published var failureReason: String?
    @Published var showLoader: Bool = true
    @Published var isMuted: Bool = true
    @Published var isWebRTCUnsupported: Bool = false
    @Published var isTalkbackSupported: Bool = false
    @Published var isTalking: Bool = false
    /// Set when the stream can't be established (offer rejected, signaling error, ICE failure or
    /// timeout), so the in-app player can cascade to the next streaming method.
    @Published var didFail: Bool = false

    /// Invoked on offer rejection, signaling error, ICE failure or timeout. Used by the
    /// notification extension to fall back; the SwiftUI player leaves it `nil` and observes the
    /// published properties instead.
    var onFailure: (() -> Void)?

    init(server: Server, cameraEntityId: String, supportsTalkback: Bool = false) {
        self.server = server
        self.cameraEntityId = cameraEntityId
        self.supportsTalkback = supportsTalkback
    }

    deinit {
        offerSubscription?.cancel()
        timeoutWorkItem?.cancel()
        webRTCClient?.closeConnection()
    }

    func toggleTalkback() {}

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

    /// Registers the view that remote video frames should be rendered into. The peer connection is
    /// created asynchronously (after the client config is fetched), so the renderer is stored and
    /// attached once the connection exists.
    func attach(renderer: RTCVideoRenderer) {
        self.renderer = renderer
        webRTCClient?.renderRemoteVideo(to: renderer)
    }

    /// Called when the first frame is rendered.
    func handleVideoRendered() {
        cancelTimeout()
        showLoader = false
    }

    // MARK: - WebRTC

    func start() {
        tearDownConnection()
        showLoader = true
        failureReason = nil
        didFail = false

        guard let api = Current.api(for: server) else {
            assertionFailure("API for server is nil")
            // Fail instead of returning silently so the player falls back rather than
            // leaving the loader spinning with no connection attempt.
            handleFailure(reason: nil)
            return
        }

        scheduleTimeout()
        let token = connectionToken

        // Same flow as the frontend player: ask the server for the client configuration (ICE
        // servers, including any user-configured TURN, and trickle-ICE support) before creating
        // the peer connection.
        api.connection.send(.init(type: .webSocket(Constants.clientConfig.rawValue), data: [
            "entity_id": cameraEntityId,
        ])).promise.pipe { [weak self] result in
            switch result {
            case let .fulfilled(data):
                self?.startConnection(configuration: .init(data: data), api: api, token: token)
            case let .rejected(error):
                Current.Log.error("WebRTC client config fetch failed, using fallback: \(error.localizedDescription)")
                self?.startConnection(configuration: .fallback, api: api, token: token)
            }
        }
    }

    func stop() {
        cancelTimeout()
        tearDownConnection()
    }

    private func startConnection(configuration: WebRTCClientConfiguration, api: HomeAssistantAPI, token: UUID) {
        guard token == connectionToken else { return }
        let client = WebRTCClient(configuration: configuration)
        webRTCClient = client
        client.delegate = self
        if let renderer {
            client.renderRemoteVideo(to: renderer)
        }
        client.offer(waitForCandidates: configuration.getCandidatesUpfront) { [weak self] sdp in
            DispatchQueue.main.async {
                guard let self, token == self.connectionToken else { return }
                self.sendOffer(sdp, api: api)
            }
        }
    }

    private func sendOffer(_ sdp: String, api: HomeAssistantAPI) {
        offerSubscription = api.connection.subscribe(to: .init(type: .webSocket(Constants.offer.rawValue), data: [
            "entity_id": cameraEntityId,
            "offer": sdp,
        ]), initiated: { [weak self] result in
            switch result {
            case let .success(data):
                Current.Log.verbose("WebRTC offer sent successfully: \(data)")
            case let .failure(error):
                Current.Log.error("Failed to send WebRTC offer: \(error.localizedDescription)")
                // Check if the error indicates WebRTC is not supported
                if error.localizedDescription.contains("does not support WebRTC") ||
                    error.localizedDescription.contains("frontend_stream_types") {
                    self?.isWebRTCUnsupported = true
                }
                self?.handleFailure(reason: error.localizedDescription)
            }
        }, handler: { [weak self] _, data in
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
            case .error:
                handleErrorEvent(data)
            case .unknown:
                Current.Log.warning("Unknown WebRTC signal type: \(typeString)")
            }
        })
    }

    private func tearDownConnection() {
        connectionToken = UUID()
        offerSubscription?.cancel()
        offerSubscription = nil
        webRTCClient?.closeConnection()
        webRTCClient = nil
        sessionId = nil
        pendingCandidates.removeAll()
    }

    private func scheduleTimeout() {
        timeoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard showLoader, failureReason == nil else { return }
            Current.Log.error("WebRTC stream for \(cameraEntityId) timed out before first frame")
            handleFailure(reason: nil)
        }
        timeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.connectionTimeout, execute: workItem)
    }

    private func cancelTimeout() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
    }

    private func handleFailure(reason: String?) {
        cancelTimeout()
        showLoader = false
        if let reason {
            failureReason = reason
        }
        didFail = true
        onFailure?()
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
        guard let candidateDict: [String: Any] = try? data.decode("candidate"),
              let candidateStr = candidateDict["candidate"] as? String,
              !candidateStr.isEmpty else {
            // An empty/null candidate signals end-of-candidates; nothing to add.
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
                Current.Log.error("Failed to add remote candidate: \(error.localizedDescription)")
            }
        }
    }

    private func handleErrorEvent(_ data: HAData) {
        let code: String? = try? data.decode("code")
        let message: String? = try? data.decode("message")
        Current.Log.error("WebRTC signaling error (\(code ?? "unknown")): \(message ?? "no message")")
        handleFailure(reason: message ?? code)
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
        api.connection.send(.init(type: .webSocket(Constants.candidate.rawValue), data: [
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
        // WebRTC delegate callbacks arrive on its signaling thread; all view model state is
        // main-thread confined.
        DispatchQueue.main.async { [weak self] in
            self?.sendCandidate(candidate)
        }
    }

    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        Current.Log.info("WebRTC connection state changed to: \(state)")
        guard state == .failed else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Ignore state changes from a connection that was already torn down/replaced.
            guard client === webRTCClient else { return }
            handleFailure(reason: nil)
        }
    }

    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        Current.Log.info("WebRTC client received data of size: \(data.count) bytes")
    }
}
