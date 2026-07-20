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
    /// Set while an offer waits for ICE gathering to finish (candidates-upfront mode); invoked
    /// from the gathering-state delegate callback once the local description is complete.
    private var iceGatheringCompletionHandler: (() -> Void)?

    @available(*, unavailable)
    override init() {
        fatalError("WebRTCClient:init is unavailable")
    }

    init(configuration: WebRTCClientConfiguration) {
        let config = RTCConfiguration()
        config.iceServers = configuration.iceServers

        // Unified plan is more superior than planB
        config.sdpSemantics = .unifiedPlan

        if configuration.getCandidatesUpfront {
            // The backend needs every candidate inside the offer, so gather once and wait for the
            // gathering state to reach `.complete` (which `.gatherContinually` never does).
            config.continualGatheringPolicy = .gatherOnce
        } else {
            // gatherContinually will let WebRTC to listen to any network changes and send any new
            // candidates to the other client
            config.continualGatheringPolicy = .gatherContinually
        }

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

    /// Creates an offer and returns its SDP. With `waitForCandidates` (candidates-upfront
    /// backends), the completion fires only after ICE gathering completes, with a local
    /// description that already contains every gathered candidate.
    func offer(waitForCandidates: Bool, completion: @escaping (_ sdp: String) -> Void) {
        let constrains = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )
        peerConnection.offer(for: constrains) { [weak self] sdp, error in
            guard let self, let sdp else {
                Current.Log.error("Failed to create WebRTC offer: \(error?.localizedDescription ?? "unknown error")")
                return
            }

            peerConnection.setLocalDescription(sdp, completionHandler: { [weak self] _ in
                guard let self else { return }
                if waitForCandidates {
                    iceGatheringCompletionHandler = { [weak self] in
                        guard let self else { return }
                        completion(peerConnection.localDescription?.sdp ?? sdp.sdp)
                    }
                    // Gathering may already have finished before the handler was set.
                    if peerConnection.iceGatheringState == .complete {
                        flushIceGatheringCompletionHandler()
                    }
                } else {
                    completion(sdp.sdp)
                }
            })
        }
    }

    func set(remoteSdp: RTCSessionDescription, completion: @escaping (Error?) -> Void) {
        peerConnection.setRemoteDescription(remoteSdp) { [weak self] error in
            if let error {
                Current.Log.error("Failed to set remote description: \(error.localizedDescription)")
            } else {
                self?.setRemoteAudioTrack()
            }
            completion(error)
        }
    }

    func set(remoteCandidate: RTCIceCandidate, completion: @escaping (Error?) -> Void) {
        peerConnection.add(remoteCandidate, completionHandler: completion)
    }

    func renderRemoteVideo(to renderer: RTCVideoRenderer) {
        remoteVideoTrack?.add(renderer)
    }

    func muteAudio() {
        remoteAudioTrack?.isEnabled = false
    }

    func unmuteAudio() {
        remoteAudioTrack?.isEnabled = true
    }

    func isAudioMuted() -> Bool {
        guard let remoteAudioTrack else { return true }
        return !remoteAudioTrack.isEnabled
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
        remoteVideoTrack = videoTransceiver?.receiver.track as? RTCVideoTrack
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

    private func flushIceGatheringCompletionHandler() {
        iceGatheringCompletionHandler?()
        iceGatheringCompletionHandler = nil
    }

    private func setRemoteAudioTrack() {
        guard let audioTransceiver = peerConnection.transceivers.first(where: { $0.mediaType == .audio }) else {
            Current.Log.warning("No audio transceiver found")
            return
        }
        guard let audioTrack = audioTransceiver.receiver.track as? RTCAudioTrack else {
            Current.Log.warning("Remote track is not an RTCAudioTrack")
            return
        }
        remoteAudioTrack = audioTrack
        remoteAudioTrack?.isEnabled = false
        Current.Log.info("Remote audio track set successfully")
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
        if newState == .complete {
            flushIceGatheringCompletionHandler()
        }
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
