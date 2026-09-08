import AudioToolbox
import AVFoundation
import Foundation
import Shared
import WebRTC

/// Delegate protocol for WebRTCClient events.
protocol WebRTCClientDelegate: AnyObject {
    /// Called when a new ICE candidate is discovered.
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate)
    /// Called when the ICE connection state changes.
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState)
    /// Called when data is received over the data channel.
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data)
}

/// Custom WebRTC audio device that supports playout only and never opens input.
final class PlaybackOnlyRTCAudioDevice: NSObject, RTCAudioDevice {
    private enum Constants {
        static let sampleRate: Double = 48000
        static let channels: Int = 1
    }

    var deviceInputSampleRate: Double { Constants.sampleRate }
    var inputIOBufferDuration: TimeInterval { 0.01 }
    var inputNumberOfChannels: Int { 0 }
    var inputLatency: TimeInterval { 0 }
    var deviceOutputSampleRate: Double { Constants.sampleRate }
    var outputIOBufferDuration: TimeInterval { 0.01 }
    var outputNumberOfChannels: Int { Constants.channels }
    var outputLatency: TimeInterval { AVAudioSession.sharedInstance().outputLatency }

    private(set) var isInitialized = false
    private(set) var isPlayoutInitialized = false
    private(set) var isPlaying = false
    private(set) var isRecordingInitialized = true
    private(set) var isRecording = false

    private weak var delegateRef: RTCAudioDeviceDelegate?
    private var outputAudioUnit: AudioUnit?

    func initialize(with delegate: any RTCAudioDeviceDelegate) -> Bool {
        delegateRef = delegate
        isInitialized = true
        return true
    }

    func terminateDevice() -> Bool {
        _ = stopPlayout()
        disposeAudioUnit()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        delegateRef = nil
        isInitialized = false
        return true
    }

    func initializePlayout() -> Bool {
        guard isInitialized || delegateRef != nil else { return false }
        if isPlayoutInitialized {
            return true
        }
        guard configureAudioSessionForPlayback(), setupOutputAudioUnit() else {
            return false
        }
        isPlayoutInitialized = true
        return true
    }

    func startPlayout() -> Bool {
        if !isPlayoutInitialized, !initializePlayout() {
            return false
        }
        guard let outputAudioUnit else { return false }
        if isPlaying {
            return true
        }
        let startResult = AudioOutputUnitStart(outputAudioUnit)
        guard startResult == noErr else {
            return false
        }
        isPlaying = true
        return true
    }

    func stopPlayout() -> Bool {
        guard let outputAudioUnit else {
            isPlaying = false
            return true
        }
        let stopResult = AudioOutputUnitStop(outputAudioUnit)
        if stopResult == noErr {
            isPlaying = false
            return true
        }
        return false
    }

    func initializeRecording() -> Bool {
        // Intentionally unsupported to avoid microphone usage.
        isRecordingInitialized = true
        return true
    }

    func startRecording() -> Bool {
        // Report success without activating input path.
        isRecording = false
        return true
    }

    func stopRecording() -> Bool {
        isRecording = false
        return true
    }

    private func configureAudioSessionForPlayback() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try session.setPreferredSampleRate(Constants.sampleRate)
            try session.setPreferredIOBufferDuration(0.01)
            try session.setActive(true)
            return true
        } catch {
            return false
        }
    }

    private func setupOutputAudioUnit() -> Bool {
        if outputAudioUnit != nil {
            return true
        }

        var description = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_RemoteIO,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        guard let component = AudioComponentFindNext(nil, &description) else {
            return false
        }

        var maybeAudioUnit: AudioUnit?
        guard AudioComponentInstanceNew(component, &maybeAudioUnit) == noErr, let audioUnit = maybeAudioUnit else {
            return false
        }

        var enableOutput: UInt32 = 1
        var disableInput: UInt32 = 0
        guard AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Output,
            0,
            &enableOutput,
            UInt32(MemoryLayout.size(ofValue: enableOutput))
        ) == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            return false
        }

        guard AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Input,
            1,
            &disableInput,
            UInt32(MemoryLayout.size(ofValue: disableInput))
        ) == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            return false
        }

        var streamFormat = AudioStreamBasicDescription(
            mSampleRate: Constants.sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: UInt32(Constants.channels),
            mBitsPerChannel: 16,
            mReserved: 0
        )

        guard AudioUnitSetProperty(
            audioUnit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            0,
            &streamFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        ) == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            return false
        }

        var renderCallback = AURenderCallbackStruct(
            inputProc: PlaybackOnlyRTCAudioDevice.renderCallback,
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
        )

        guard AudioUnitSetProperty(
            audioUnit,
            kAudioUnitProperty_SetRenderCallback,
            kAudioUnitScope_Input,
            0,
            &renderCallback,
            UInt32(MemoryLayout<AURenderCallbackStruct>.size)
        ) == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            return false
        }

        guard AudioUnitInitialize(audioUnit) == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            return false
        }

        outputAudioUnit = audioUnit
        return true
    }

    private func disposeAudioUnit() {
        guard let outputAudioUnit else { return }
        AudioOutputUnitStop(outputAudioUnit)
        AudioUnitUninitialize(outputAudioUnit)
        AudioComponentInstanceDispose(outputAudioUnit)
        self.outputAudioUnit = nil
        isPlayoutInitialized = false
        isPlaying = false
    }

    private func handleRender(
        actionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        timestamp: UnsafePointer<AudioTimeStamp>,
        busNumber: UInt32,
        frameCount: UInt32,
        ioData: UnsafeMutablePointer<AudioBufferList>?
    ) -> OSStatus {
        guard let ioData, let delegateRef else { return noErr }
        return delegateRef.getPlayoutData(actionFlags, timestamp, Int(busNumber), frameCount, ioData)
    }

    private static let renderCallback: AURenderCallback = {
        inRefCon,
            ioActionFlags,
            inTimeStamp,
            inBusNumber,
            inNumberFrames,
            ioData
            -> OSStatus in
        let owner = Unmanaged<PlaybackOnlyRTCAudioDevice>.fromOpaque(inRefCon).takeUnretainedValue()
        return owner.handleRender(
            actionFlags: ioActionFlags,
            timestamp: inTimeStamp,
            busNumber: inBusNumber,
            frameCount: inNumberFrames,
            ioData: ioData
        )
    }
}

/// WebRTCClient manages a WebRTC peer connection, media tracks, and data channels.
/// It abstracts the setup and control of a WebRTC session for use in the Home Assistant iOS app.
///
/// - Note: Based on example project from WebRTC iOS SDK https://github.com/stasel/WebRTC
final class WebRTCClient: NSObject {
    private static let playbackOnlyAudioDevice = PlaybackOnlyRTCAudioDevice()

    // The `RTCPeerConnectionFactory` is in charge of creating new RTCPeerConnection instances.
    // A new RTCPeerConnection should be created every new call, but the factory is shared.
    private static let factory: RTCPeerConnectionFactory = {
        WebRTCFieldTrials.registerBeforeCreatingFactory()
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(
            encoderFactory: videoEncoderFactory,
            decoderFactory: videoDecoderFactory,
            audioDevice: playbackOnlyAudioDevice
        )
    }()

    weak var delegate: WebRTCClientDelegate?
    private let peerConnection: RTCPeerConnection
    private var remoteVideoTrack: RTCVideoTrack?
    private var remoteAudioTrack: RTCAudioTrack?
    private var localDataChannel: RTCDataChannel?
    private var remoteDataChannel: RTCDataChannel?
    /// The view remote video renders into. Held here because the track that ends up carrying the
    /// video is only known once the remote description has been applied.
    private weak var renderer: RTCVideoRenderer?
    /// Remote audio starts muted, matching the player's default. `unmuteAudio()` flips this so a
    /// track adopted later comes up in the state the user last chose rather than blaring.
    private var isRemoteAudioEnabled = false

    @available(*, unavailable)
    override init() {
        fatalError("WebRTCClient:init is unavailable")
    }

    init(configuration: WebRTCClientConfiguration) {
        let config = RTCConfiguration()
        config.iceServers = configuration.iceServers

        // Unified plan is more superior than planB
        config.sdpSemantics = .unifiedPlan

        // One transport for audio and video from the start, instead of gathering and checking a
        // full candidate set per m-line until the answer bundles them. Every WebRTC answerer
        // bundles, so the only effect is half the candidates and half the connectivity checks.
        config.bundlePolicy = .maxBundle

        // gatherContinually lets WebRTC listen for network changes and trickle any new candidates
        // to the other side, which is what the frontend's peer connection does by default.
        config.continualGatheringPolicy = .gatherContinually

        // Left to itself this gathers on every interface the phone has, and on cellular that is a
        // lot of them: several private pdp_ip addresses, the 464XLAT address, link-local and
        // unique-local IPv6, each in a UDP and a TCP flavour. Device logs showed close to fifty
        // candidates offered for a camera reachable over exactly one of them, and the checks then
        // worked through the useless pairs first — nine seconds of them before the relay pair won.
        // A browser never offers that set, which is why the frontend connects on the same network
        // while this took ten seconds or gave up.
        //
        // The interfaces themselves are trimmed by `WebRTCFieldTrials`: with the path monitor on,
        // libwebrtc ignores every interface that is not part of the current network path, which
        // on cellular leaves the one pdp_ip that can actually reach anything — the same set the
        // frontend's player gets, since WKWebView only gathers on the default route. What is left
        // to drop here is the flavour of candidate that could never carry the stream even there: a
        // TCP host candidate on a private cellular address is unreachable from the server (TURN
        // over TCP is unaffected, it comes from the ICE server list), and so is a link-local one.
        //
        // Relay candidates are deliberately left alone. Behind carrier-grade NAT the relay is the
        // only kind that can carry the stream at all — host addresses are private and the reflexive
        // one is not reachable inbound — so every relay candidate is a separate chance for the
        // stream to come up, not redundancy worth pruning.
        config.tcpCandidatePolicy = .disabled
        config.disableLinkLocalNetworks = true

        // Gather a candidate up front rather than starting from cold when the offer is created, so
        // the offer carries one instead of the backend waiting on the first trickled candidate —
        // which it cannot even be sent before it answers with a session id.
        config.iceCandidatePoolSize = 1

        // Define media constraints. DtlsSrtpKeyAgreement is required to be true to be able to connect with web
        // browsers.
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue]
        )

        guard let peerConnection = WebRTCClient.factory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: nil
        ) else {
            fatalError("Could not create new RTCPeerConnection")
        }

        self.peerConnection = peerConnection
        super.init()
        createMediaTracks()
        if let dataChannelLabel = configuration.dataChannelLabel {
            createDataChannel(label: dataChannelLabel)
        }

        self.peerConnection.delegate = self
    }

    func closeConnection() {
        peerConnection.close()
    }

    // MARK: Signaling

    /// Creates an offer and returns its SDP.
    ///
    /// The SDP comes back from `localDescription` rather than from the description that was just
    /// created, so it already carries whatever ICE candidates have been gathered by then. That is
    /// the same thing the frontend does by appending its pending candidates to the offer before
    /// sending it, and it is what lets a backend that never trickles candidates back still find a
    /// path to us. The rest keep arriving over the signaling channel as usual.
    func offer(completion: @escaping (_ sdp: String) -> Void) {
        let constrains = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )
        peerConnection.offer(for: constrains) { [weak self] sdp, error in
            guard let self, let sdp else {
                Current.Log.error("Failed to create WebRTC offer: \(error?.localizedDescription ?? "unknown error")")
                return
            }

            peerConnection.setLocalDescription(sdp, completionHandler: { [weak self] error in
                guard let self else { return }
                if let error {
                    Current.Log.error("Failed to set local description: \(error.localizedDescription)")
                }
                completion(peerConnection.localDescription?.sdp ?? sdp.sdp)
            })
        }
    }

    func set(remoteSdp: RTCSessionDescription, completion: @escaping (Error?) -> Void) {
        peerConnection.setRemoteDescription(remoteSdp) { [weak self] error in
            if let error {
                Current.Log.error("Failed to set remote description: \(error.localizedDescription)")
            } else {
                self?.adoptRemoteTracks()
            }
            completion(error)
        }
    }

    func set(remoteCandidate: RTCIceCandidate, completion: @escaping (Error?) -> Void) {
        peerConnection.add(remoteCandidate, completionHandler: completion)
    }

    func renderRemoteVideo(to renderer: RTCVideoRenderer) {
        self.renderer = renderer
        remoteVideoTrack?.add(renderer)
    }

    func muteAudio() {
        isRemoteAudioEnabled = false
        remoteAudioTrack?.isEnabled = false
    }

    func unmuteAudio() {
        isRemoteAudioEnabled = true
        remoteAudioTrack?.isEnabled = true
    }

    func isAudioMuted() -> Bool {
        guard let remoteAudioTrack else { return true }
        return !remoteAudioTrack.isEnabled
    }

    /// Whether the peer connection can still carry media. iOS suspends the app after a short spell
    /// in the background and the connection does not survive that, so the player asks rather than
    /// assumes when it comes back to the foreground.
    var isConnectionAlive: Bool {
        let deadStates: [RTCPeerConnectionState] = [.disconnected, .failed, .closed]
        return !deadStates.contains(peerConnection.connectionState)
    }

    private func createMediaTracks() {
        // Receive-only transceivers, matching the frontend player: we never send media, so no
        // local track or capturer is needed (RTCCameraVideoCapturer is unavailable in app
        // extensions anyway), and the offer negotiates recvonly m-lines.
        let audioTransceiverInit = RTCRtpTransceiverInit()
        audioTransceiverInit.direction = .recvOnly
        peerConnection.addTransceiver(of: .audio, init: audioTransceiverInit)

        let videoTransceiverInit = RTCRtpTransceiverInit()
        videoTransceiverInit.direction = .recvOnly
        let videoTransceiver = peerConnection.addTransceiver(of: .video, init: videoTransceiverInit)
        // The receiver carries a track before negotiation even starts, so adopt it now to give an
        // early renderer something to attach to. Whatever the answer actually negotiates takes its
        // place once the remote description lands.
        adopt(track: videoTransceiver?.receiver.track)
    }

    /// The counterpart of the frontend player's `ontrack`: wires up whichever track the peer
    /// connection hands over, instead of assuming the media arrives on the transceiver the offer
    /// created. Backends are free to answer with the m-lines arranged differently, and a video
    /// track picked up front would then render nothing at all.
    ///
    /// Peer connection callbacks arrive on WebRTC's signaling thread while the renderer is
    /// registered from the main one, so the track state is only ever touched on the main queue.
    private func adopt(track: RTCMediaStreamTrack?) {
        guard let track else { return }
        DispatchQueue.main.async { [weak self] in
            self?.attach(track: track)
        }
    }

    private func attach(track: RTCMediaStreamTrack) {
        if let videoTrack = track as? RTCVideoTrack {
            guard videoTrack !== remoteVideoTrack else { return }
            if let renderer {
                remoteVideoTrack?.remove(renderer)
                videoTrack.add(renderer)
            }
            remoteVideoTrack = videoTrack
        } else if let audioTrack = track as? RTCAudioTrack {
            remoteAudioTrack = audioTrack
            audioTrack.isEnabled = isRemoteAudioEnabled
        }
    }

    /// Sweeps the negotiated transceivers once the answer is applied, for backends whose tracks are
    /// already live by the time `didStartReceivingOn` would have fired.
    private func adoptRemoteTracks() {
        for transceiver in peerConnection.transceivers {
            adopt(track: transceiver.receiver.track)
        }
    }

    private func createDataChannel(label: String) {
        let configuration = RTCDataChannelConfiguration()
        guard let dataChannel = peerConnection.dataChannel(forLabel: label, configuration: configuration) else {
            Current.Log.warning("Could not create WebRTC data channel \(label)")
            return
        }
        dataChannel.delegate = self
        localDataChannel = dataChannel
    }
}

// MARK: - RTCPeerConnectionDelegate

/// Handles RTCPeerConnection events and forwards relevant events to the delegate.
extension WebRTCClient: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        Current.Log.info("peerConnection new signaling state: \(stateChanged)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        Current.Log.info("peerConnection did add stream")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        Current.Log.info("peerConnection did remove stream")
    }

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        Current.Log.info("peerConnection should negotiate")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Current.Log.info("peerConnection new connection state: \(newState)")
        delegate?.webRTCClient(self, didChangeConnectionState: newState)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        Current.Log.info("peerConnection new gathering state: \(newState)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didStartReceivingOn transceiver: RTCRtpTransceiver) {
        Current.Log.info("peerConnection did start receiving on transceiver \(transceiver.mediaType)")
        adopt(track: transceiver.receiver.track)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        Current.Log.info("peerConnection did generate candidate: \(candidate)")
        delegate?.webRTCClient(self, didDiscoverLocalCandidate: candidate)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        Current.Log.info("peerConnection did remove candidate(s)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        Current.Log.info("peerConnection did open data channel")
        dataChannel.delegate = self
        remoteDataChannel = dataChannel
    }
}

// MARK: - RTCDataChannelDelegate

/// Handles RTCDataChannel events and forwards data to the delegate.
extension WebRTCClient: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        Current.Log.info("dataChannel did change state: \(dataChannel.readyState)")
    }

    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        delegate?.webRTCClient(self, didReceiveData: buffer.data)
    }
}
