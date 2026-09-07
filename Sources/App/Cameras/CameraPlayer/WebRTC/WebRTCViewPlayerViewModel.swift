import Foundation
import HAKit
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
    /// to HLS instead of showing a spinner forever (e.g. remote connections that need TURN, or a
    /// camera whose video codec the bundled WebRTC build has no decoder for).
    ///
    /// Generous, because it is the whole negotiation being measured: gathering relay candidates
    /// over cellular and checking them takes the better part of ten seconds on a healthy 5G link,
    /// and cutting that short sends a camera that would have played to a lesser stream.
    private static let connectionTimeout: TimeInterval = 25

    /// How long a dropped connection is given to mend itself before the stream is rebuilt.
    ///
    /// WebRTC re-checks its candidates after a brief interruption and often recovers on its own,
    /// so an immediate rebuild would throw away a stream that was coming back. A connection lost
    /// because the phone actually moved between networks — cellular to Wi-Fi and back — never
    /// returns on its own, and sitting on it is what leaves a frozen picture until the player is
    /// reopened.
    private static let disconnectedGracePeriod: TimeInterval = 5

    /// How many times a broken connection is rebuilt before the player gives up and cascades to the
    /// next streaming method. The frontend restarts ICE on the same peer connection; core mints a
    /// session per offer, so the app starts a fresh one instead — the effect is the same, another
    /// pass at gathering candidates before anything is declared unplayable. Reaching a connected
    /// state resets the count, so a long watch isn't limited by an interruption it recovered from.
    private static let maxConnectionRetries = 2

    /// Mirrors `HIDDEN_CLEANUP_DELAY` in the frontend player: a stream gets this long out of sight
    /// before coming back to the foreground counts as needing a fresh one.
    private static let backgroundTeardownDelay: TimeInterval = 60

    var webRTCClient: WebRTCClient?
    private var sessionId: String?
    private var pendingCandidates: [RTCIceCandidate] = []
    private var offerSubscription: HACancellable?
    private var timeoutWorkItem: DispatchWorkItem?
    private var disconnectRecoveryWorkItem: DispatchWorkItem?
    /// Regenerated on every start/teardown so async setup steps (config fetch, offer creation)
    /// from a previous attempt are ignored instead of resurrecting a torn-down connection.
    private var connectionToken = UUID()
    private var connectionRetries = 0
    private weak var renderer: RTCVideoRenderer?
    /// Set while the player is meant to be streaming — between `start()` and `stop()` — so the
    /// scene-phase hooks know whether there is anything to suspend or resume.
    private var isActive = false
    private var backgroundedAt: Date?
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
        disconnectRecoveryWorkItem?.cancel()
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
        isActive = true
        connectionRetries = 0
        cancelTimeout()
        scheduleTimeout()
        beginConnection()
    }

    func stop() {
        isActive = false
        backgroundedAt = nil
        cancelTimeout()
        cancelDisconnectRecovery()
        tearDownConnection()
    }

    /// Called when the app leaves the foreground. Nothing is torn down here: iOS keeps the app
    /// running for a short while, and a stream that survives a quick trip away should still be
    /// playing when the user comes back, as it is in the frontend.
    func handleAppBackgrounded() {
        guard isActive, backgroundedAt == nil else { return }
        backgroundedAt = Current.date()
    }

    /// Called when the app returns to the foreground, mirroring the frontend player's
    /// `visibilitychange` handling: a stream that outlived being hidden keeps playing, and one that
    /// did not is started again rather than leaving the last frame frozen on screen.
    func handleAppForegrounded() {
        guard isActive, let hiddenSince = backgroundedAt else { return }
        let hiddenDuration = Current.date().timeIntervalSince(hiddenSince)
        backgroundedAt = nil
        // A connection still being set up has no client yet; restarting would throw away an attempt
        // that is still in flight, which matters because `.inactive` also covers a passing overlay.
        guard let webRTCClient else { return }
        guard hiddenDuration >= Self.backgroundTeardownDelay || !webRTCClient.isConnectionAlive else { return }
        Current.Log.info("Restarting WebRTC stream for \(cameraEntityId) after \(Int(hiddenDuration))s hidden")
        start()
    }

    private func beginConnection() {
        cancelDisconnectRecovery()
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

        let token = connectionToken

        // Same flow as the frontend player: ask the server for the client configuration — the ICE
        // servers, including any user-configured TURN, and the data channel some cameras need —
        // before creating the peer connection.
        api.connection.send(.init(type: .webSocket(Constants.clientConfig.rawValue), data: [
            "entity_id": cameraEntityId,
        ])) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, token == self.connectionToken else { return }
                switch result {
                case let .success(data):
                    self.startConnection(configuration: .init(data: data), api: api, token: token)
                case let .failure(error):
                    // Core guards this command with the same `require_webrtc_support` check as the
                    // offer, so a rejection here already tells us the camera has no WebRTC stream
                    // type. Cascading now beats sending an offer that is certain to be refused.
                    if Self.isWebRTCUnsupported(error: error) {
                        Current.Log.info("Camera \(self.cameraEntityId) does not support WebRTC")
                        self.isWebRTCUnsupported = true
                        self.handleFailure(reason: nil)
                        return
                    }
                    Current.Log.error(
                        "WebRTC client config fetch failed, using fallback: \(error.localizedDescription)"
                    )
                    self.startConnection(configuration: .fallback, api: api, token: token)
                }
            }
        }
    }

    private func startConnection(configuration: WebRTCClientConfiguration, api: HomeAssistantAPI, token: UUID) {
        guard token == connectionToken else { return }
        let client = WebRTCClient(configuration: configuration)
        webRTCClient = client
        client.delegate = self
        if let renderer {
            client.renderRemoteVideo(to: renderer)
        }
        client.offer { [weak self] sdp in
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
                if Self.isWebRTCUnsupported(error: error) {
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

    /// Whether an error from core means this camera has no WebRTC stream type at all, as opposed
    /// to a stream that could not be established. Core reports both from `camera/webrtc/*` under
    /// the same error code, so the message is what separates them.
    private static func isWebRTCUnsupported(error: Error) -> Bool {
        if let haError = error as? HAError, case let .external(external) = haError {
            return isWebRTCUnsupported(message: external.message)
        }
        return isWebRTCUnsupported(message: error.localizedDescription)
    }

    private static func isWebRTCUnsupported(message: String) -> Bool {
        message.contains("does not support WebRTC") || message.contains("frontend_stream_types")
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

    /// Waits out a short interruption before rebuilding the stream, so WebRTC gets the chance to
    /// re-check its candidates and carry on. Scheduled once per interruption; reaching a connected
    /// state again cancels it.
    private func scheduleDisconnectRecovery() {
        guard disconnectRecoveryWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            disconnectRecoveryWorkItem = nil
            Current.Log.info("WebRTC stream for \(cameraEntityId) stayed disconnected, rebuilding it")
            handleConnectionFailure()
        }
        disconnectRecoveryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.disconnectedGracePeriod, execute: workItem)
    }

    private func cancelDisconnectRecovery() {
        disconnectRecoveryWorkItem?.cancel()
        disconnectRecoveryWorkItem = nil
    }

    /// A connection that broke gets rebuilt before the player gives up on WebRTC, the way the
    /// frontend restarts ICE instead of surrendering the stream on the first failure.
    private func handleConnectionFailure() {
        cancelDisconnectRecovery()
        guard connectionRetries < Self.maxConnectionRetries else {
            handleFailure(reason: nil)
            return
        }
        connectionRetries += 1
        Current.Log.info("WebRTC connection for \(cameraEntityId) failed, rebuilding it")
        // A stream that was already playing cancelled its timeout when the first frame arrived, so
        // the rebuild needs a fresh one — otherwise a retry that never connects leaves the loader
        // spinning with nothing to cascade it onwards.
        cancelTimeout()
        scheduleTimeout()
        beginConnection()
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
        // JSON numbers arrive bridged, so read the index through NSNumber rather than casting
        // straight to Int32 — a failed cast would silently file a video candidate under the audio
        // m-line. When the backend sends neither field the frontend defaults `sdpMid` to "0",
        // because a candidate needs one of the two to be accepted at all.
        let sdpMLineIndex = (candidateDict["sdpMLineIndex"] as? NSNumber)?.int32Value ?? 0
        let sdpMidFallback: String? = candidateDict["sdpMLineIndex"] == nil ? "0" : nil
        let sdpMid = candidateDict["sdpMid"] as? String ?? sdpMidFallback
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
        // A camera that passes core's `require_webrtc_support` check but has no WebRTC provider
        // behind it reports "Camera does not support WebRTC" here, as a signaling event rather
        // than a rejected request, so this path needs the same check the request path makes.
        if let message, Self.isWebRTCUnsupported(message: message) {
            isWebRTCUnsupported = true
        }
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
        ])) { result in
            switch result {
            case let .success(data):
                Current.Log.verbose("Sent candidate: \(data)")
            case let .failure(error):
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
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Ignore state changes from a connection that was already torn down/replaced.
            guard client === webRTCClient else { return }
            switch state {
            case .connected, .completed:
                // Back on its feet, and the attempts it took to get here shouldn't count against a
                // later interruption in what may be a long watch.
                cancelDisconnectRecovery()
                connectionRetries = 0
            case .failed:
                handleConnectionFailure()
            case .disconnected:
                // Not fatal on its own: WebRTC re-checks and often recovers. Moving between
                // networks lands here too and never recovers, which is what the grace period sorts
                // out one way or the other.
                scheduleDisconnectRecovery()
            default:
                break
            }
        }
    }

    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        Current.Log.info("WebRTC client received data of size: \(data.count) bytes")
    }
}
