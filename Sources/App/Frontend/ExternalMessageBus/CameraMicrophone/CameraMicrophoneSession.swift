import Foundation
import HAKit
import Shared
import WebRTC

final class CameraMicrophoneSession: CameraMicrophoneSessionProtocol {
    struct Timing {
        var connectionTimeout: TimeInterval
        var disconnectedGracePeriod: TimeInterval

        static let production = Timing(connectionTimeout: 25, disconnectedGracePeriod: 5)
    }

    private enum State {
        case idle
        case starting
        case connected
        case ended
    }

    private typealias Command = WebRTCViewPlayerViewModel.Constants

    let cameraEntityId: String
    var onEnd: ((CameraMicrophoneError) -> Void)?

    var isConnected: Bool {
        state == .connected
    }

    private let server: Server
    private let makeClient: (WebRTCClientConfiguration) -> WebRTCStreamClient
    private let requestMicrophonePermission: () async -> Bool
    private let timing: Timing

    private var state: State = .idle
    private var startCompletion: ((Result<String, CameraMicrophoneError>) -> Void)?
    private var client: WebRTCStreamClient?
    private var connectionGate: WebRTCServerConnectionGate?
    private var offerSubscription: HACancellable?
    private(set) var sessionId: String?
    private var isIceConnected = false
    private var pendingCandidates: [RTCIceCandidate] = []
    private var timeoutWorkItem: DispatchWorkItem?
    private var disconnectRecoveryWorkItem: DispatchWorkItem?

    init(
        server: Server,
        cameraEntityId: String,
        makeClient: @escaping (WebRTCClientConfiguration) -> WebRTCStreamClient = {
            WebRTCClient(configuration: $0, media: .microphone)
        },
        requestMicrophonePermission: @escaping () async -> Bool = WebRTCMicrophonePermission.request,
        timing: Timing = .production
    ) {
        self.server = server
        self.cameraEntityId = cameraEntityId
        self.makeClient = makeClient
        self.requestMicrophonePermission = requestMicrophonePermission
        self.timing = timing
    }

    deinit {
        tearDown()
    }

    func start(completion: @escaping (Result<String, CameraMicrophoneError>) -> Void) {
        guard state == .idle else {
            completion(.failure(.interrupted))
            return
        }
        state = .starting
        startCompletion = completion
        Current.Log.info("Starting camera microphone for \(cameraEntityId)")
        Task { @MainActor [weak self] in
            guard let self else { return }
            let granted = await requestMicrophonePermission()
            guard state == .starting else { return }
            guard granted else {
                finish(with: .microphoneDenied)
                return
            }
            connect()
        }
    }

    func stop() {
        finish(with: .interrupted, notifiesEnd: false)
    }

    private func connect() {
        guard let api = Current.api(for: server) else {
            finish(with: .serverUnavailable)
            return
        }
        scheduleTimeout()
        let gate = WebRTCServerConnectionGate(connection: api.connection)
        connectionGate = gate
        gate.whenReady { [weak self] isReady in
            guard let self, state == .starting else { return }
            connectionGate = nil
            guard isReady else {
                finish(with: .serverUnavailable)
                return
            }
            fetchClientConfiguration(api: api)
        }
    }

    private func fetchClientConfiguration(api: HomeAssistantAPI) {
        api.connection.send(.init(
            type: .webSocket(Command.clientConfig.rawValue),
            data: ["entity_id": cameraEntityId]
        )) { [weak self] result in
            guard let self, state == .starting else { return }
            switch result {
            case let .success(data):
                startConnection(configuration: .init(data: data), api: api)
            case let .failure(error):
                Current.Log.error(
                    "Camera microphone client config fetch failed, using fallback: \(error.localizedDescription)"
                )
                startConnection(configuration: .fallback, api: api)
            }
        }
    }

    private func startConnection(configuration: WebRTCClientConfiguration, api: HomeAssistantAPI) {
        let client = makeClient(configuration)
        self.client = client
        client.delegate = self
        client.offer { [weak self, weak client] sdp in
            DispatchQueue.main.async {
                guard let self, let client, client === self.client, self.state == .starting else { return }
                self.sendOffer(sdp, api: api)
            }
        }
    }

    private func sendOffer(_ sdp: String, api: HomeAssistantAPI) {
        offerSubscription = api.connection.subscribe(to: .init(
            type: .webSocket(Command.offer.rawValue),
            data: [
                "entity_id": cameraEntityId,
                "offer": sdp,
            ]
        ), initiated: { [weak self] result in
            guard let self, case let .failure(error) = result else { return }
            Current.Log.error("Camera microphone offer for \(cameraEntityId) failed: \(error.localizedDescription)")
            finish(with: .signalingFailed(Self.message(for: error)))
        }, handler: { [weak self] _, data in
            self?.handleSignal(data)
        })
    }

    private static func message(for error: HAError) -> String {
        if case let .external(external) = error {
            return external.message
        }
        return error.localizedDescription
    }

    private func handleSignal(_ data: HAData) {
        guard state == .starting || state == .connected else { return }
        guard let typeString: String = try? data.decode("type") else { return }
        switch WebRTCSignalType(typeString) {
        case .session:
            handleSession(data)
        case .answer:
            handleAnswer(data)
        case .candidate:
            handleCandidate(data)
        case .error:
            let code: String? = try? data.decode("code")
            let message: String? = try? data.decode("message")
            Current.Log.error("Camera microphone signaling error (\(code ?? "unknown")): \(message ?? "no message")")
            finish(with: .signalingFailed(message ?? code))
        case .unknown:
            Current.Log.warning("Unknown camera microphone signal type: \(typeString)")
        }
    }

    private func handleSession(_ data: HAData) {
        guard let sessionId: String = try? data.decode("session_id") else { return }
        self.sessionId = sessionId
        let candidates = pendingCandidates
        pendingCandidates.removeAll()
        for candidate in candidates {
            sendCandidate(candidate)
        }
        reportStartIfReady()
    }

    private func handleAnswer(_ data: HAData) {
        guard let answer: String = try? data.decode("answer") else { return }
        client?.set(remoteSdp: RTCSessionDescription(type: .answer, sdp: answer)) { error in
            if let error {
                Current.Log.error("Camera microphone failed to set remote SDP: \(error.localizedDescription)")
            }
        }
    }

    private func handleCandidate(_ data: HAData) {
        guard let candidate = WebRTCSignalingCandidate.remoteCandidate(from: data) else { return }
        client?.set(remoteCandidate: candidate) { error in
            if let error {
                Current.Log.error("Camera microphone failed to add remote candidate: \(error.localizedDescription)")
            }
        }
    }

    private func sendCandidate(_ candidate: RTCIceCandidate) {
        guard let sessionId else {
            pendingCandidates.append(candidate)
            return
        }
        guard let api = Current.api(for: server) else { return }
        api.connection.send(.init(type: .webSocket(Command.candidate.rawValue), data: [
            "entity_id": cameraEntityId,
            "session_id": sessionId,
            "candidate": WebRTCSignalingCandidate.payload(for: candidate),
        ])) { result in
            if case let .failure(error) = result {
                Current.Log.error("Camera microphone failed to send candidate: \(error.localizedDescription)")
            }
        }
    }

    private func handleConnectionState(_ connectionState: RTCIceConnectionState) {
        switch connectionState {
        case .connected, .completed:
            cancelDisconnectRecovery()
            isIceConnected = true
            reportStartIfReady()
        case .failed:
            finish(with: .connectionFailed)
        case .disconnected:
            scheduleDisconnectRecovery()
        default:
            break
        }
    }

    private func reportStartIfReady() {
        guard state == .starting, isIceConnected, let sessionId else { return }
        state = .connected
        cancelTimeout()
        Current.Log.info("Camera microphone for \(cameraEntityId) is connected in session \(sessionId)")
        let completion = startCompletion
        startCompletion = nil
        completion?(.success(sessionId))
    }

    private func finish(with error: CameraMicrophoneError, notifiesEnd: Bool = true) {
        guard state != .ended else { return }
        let wasConnected = state == .connected
        state = .ended
        tearDown()
        Current.Log.info("Camera microphone for \(cameraEntityId) ended: \(error.code)")
        if let startCompletion {
            self.startCompletion = nil
            startCompletion(.failure(error))
        } else if wasConnected, notifiesEnd {
            onEnd?(error)
        }
    }

    private func tearDown() {
        cancelTimeout()
        cancelDisconnectRecovery()
        connectionGate?.cancel()
        connectionGate = nil
        offerSubscription?.cancel()
        offerSubscription = nil
        client?.closeConnection()
        client = nil
        isIceConnected = false
        pendingCandidates.removeAll()
    }

    private func scheduleTimeout() {
        timeoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, state == .starting else { return }
            Current.Log.error("Camera microphone for \(cameraEntityId) timed out before connecting")
            finish(with: .timedOut)
        }
        timeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + timing.connectionTimeout, execute: workItem)
    }

    private func cancelTimeout() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
    }

    private func scheduleDisconnectRecovery() {
        guard disconnectRecoveryWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            disconnectRecoveryWorkItem = nil
            finish(with: .connectionFailed)
        }
        disconnectRecoveryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + timing.disconnectedGracePeriod, execute: workItem)
    }

    private func cancelDisconnectRecovery() {
        disconnectRecoveryWorkItem?.cancel()
        disconnectRecoveryWorkItem = nil
    }
}

extension CameraMicrophoneSession: WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCStreamClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        DispatchQueue.main.async { [weak self] in
            guard let self, client === self.client else { return }
            sendCandidate(candidate)
        }
    }

    func webRTCClient(_ client: WebRTCStreamClient, didChangeConnectionState state: RTCIceConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self, client === self.client else { return }
            handleConnectionState(state)
        }
    }

    func webRTCClient(_ client: WebRTCStreamClient, didReceiveData data: Data) {}
}
