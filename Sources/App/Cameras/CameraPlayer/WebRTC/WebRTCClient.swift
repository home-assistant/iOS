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
    private let mediaConstrains = [
        kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
        kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue,
    ]
    private var videoCapturer: RTCVideoCapturer?
    private var remoteVideoTrack: RTCVideoTrack?
    private var remoteAudioTrack: RTCAudioTrack?
    private var remoteDataChannel: RTCDataChannel?

    @available(*, unavailable)
    override init() {
        fatalError("WebRTCClient:init is unavailable")
    }

    required init(iceServers: [String]) {
        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: iceServers)]

        // Unified plan is more superior than planB
        config.sdpSemantics = .unifiedPlan

        // gatherContinually will let WebRTC to listen to any network changes and send any new candidates to the other
        // client
        config.continualGatheringPolicy = .gatherContinually

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

        self.peerConnection.delegate = self
    }

    func closeConnection() {
        peerConnection.close()
    }

    // MARK: Signaling

    func offer(completion: @escaping (_ sdp: RTCSessionDescription) -> Void) {
        let constrains = RTCMediaConstraints(
            mandatoryConstraints: mediaConstrains,
            optionalConstraints: nil
        )
        peerConnection.offer(for: constrains) { sdp, _ in
            guard let sdp else {
                return
            }

            self.peerConnection.setLocalDescription(sdp, completionHandler: { _ in
                completion(sdp)
            })
        }
    }

    func answer(completion: @escaping (_ sdp: RTCSessionDescription) -> Void) {
        let constrains = RTCMediaConstraints(
            mandatoryConstraints: mediaConstrains,
            optionalConstraints: nil
        )
        peerConnection.answer(for: constrains) { sdp, _ in
            guard let sdp else {
                return
            }

            self.peerConnection.setLocalDescription(sdp, completionHandler: { _ in
                completion(sdp)
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
        let streamId = "stream"
        let videoTrack = createVideoTrack()
        peerConnection.add(videoTrack, streamIds: [streamId])
        remoteVideoTrack = peerConnection.transceivers.first { $0.mediaType == .video }?.receiver
            .track as? RTCVideoTrack
    }

    private func createVideoTrack() -> RTCVideoTrack {
        let videoSource = WebRTCClient.factory.videoSource()

        #if targetEnvironment(simulator)
        videoCapturer = RTCFileVideoCapturer(delegate: videoSource)
        #else
        videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        #endif

        let videoTrack = WebRTCClient.factory.videoTrack(with: videoSource, trackId: "video0")
        return videoTrack
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
        remoteDataChannel = dataChannel
    }
}

extension WebRTCClient {
    private func setTrackEnabled<T: RTCMediaStreamTrack>(_ type: T.Type, isEnabled: Bool) {
        peerConnection.transceivers
            .compactMap { $0.sender.track as? T }
            .forEach { $0.isEnabled = isEnabled }
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
