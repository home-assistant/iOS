import AudioToolbox
import AVFoundation
import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 26.4, *)
final class CarPlayAssistSession: NSObject {
    typealias OnStop = () -> Void

    enum State {
        case idle
        case recording
        case processing
        case responding
        case error(String)

        var isError: Bool {
            if case .error = self { return true }
            return false
        }
    }

    private enum VoiceControlStateID: String {
        case idle
        case recording
        case processing
        case responding
    }

    weak var interfaceController: CPInterfaceController?
    var onStop: OnStop?

    private let audioSession = AVAudioSession.sharedInstance()
    private var assistService: AssistServiceProtocol
    private var audioRecorder: AudioRecorderProtocol
    private var recordingIndicatorPlayer: AVAudioPlayer?
    private var ttsAudioPlayer: AVAudioPlayer?
    private let ttsPlayer = AVPlayer()
    private var ttsPlayerItemStatusObservation: NSKeyValueObservation?
    private var ttsPlayerTimeControlObservation: NSKeyValueObservation?

    /// Serial queue protecting all mutable session state (`canSendAudioData`, `state`, `isStopped`).
    /// Callbacks from AVCaptureSession, HAKit, and NotificationCenter may arrive on arbitrary threads.
    private let stateQueue = DispatchQueue(label: "io.home-assistant.carplay-assist-session", qos: .userInteractive)
    private var canSendAudioData = false
    private var state: State = .recording
    private var isStopped = false

    private let server: Server
    private let pipelineId: String
    private let pipelineName: String

    private lazy var template: CPVoiceControlTemplate = {
        let idleState = CPVoiceControlState(
            identifier: VoiceControlStateID.idle.rawValue,
            titleVariants: [L10n.Assist.Carplay.TapToRecord.title],
            image: MaterialDesignIcons.microphoneIcon.carPlayIcon(color: .haPrimary),
            repeats: false
        )
        let idleButton = CPButton(
            image: MaterialDesignIcons.microphoneIcon.carPlayIcon(color: .haPrimary)
        ) { [weak self] _ in
            self?.restartRecording()
        }
        idleState.actionButtons = [idleButton]

        let recordingState = CPVoiceControlState(
            identifier: VoiceControlStateID.recording.rawValue,
            titleVariants: [L10n.Assist.Button.Listening.title],
            image: MaterialDesignIcons.microphoneIcon.carPlayIcon(color: .haPrimary),
            repeats: true
        )
        let processingState = CPVoiceControlState(
            identifier: VoiceControlStateID.processing.rawValue,
            titleVariants: [L10n.Assist.Carplay.Processing.title],
            image: MaterialDesignIcons.dotsHorizontalIcon.carPlayIcon(color: .haPrimary),
            repeats: true
        )
        let respondingState = CPVoiceControlState(
            identifier: VoiceControlStateID.responding.rawValue,
            titleVariants: [L10n.Assist.Carplay.Responding.title],
            image: MaterialDesignIcons.volumeHighIcon.carPlayIcon(color: .haPrimary),
            repeats: true
        )
        return CPVoiceControlTemplate(voiceControlStates: [recordingState, processingState, respondingState, idleState])
    }()

    init(
        interfaceController: CPInterfaceController?,
        server: Server,
        pipelineId: String,
        pipelineName: String,
        audioRecorder: AudioRecorderProtocol = AudioRecorder(),
        assistService: AssistServiceProtocol? = nil
    ) {
        self.interfaceController = interfaceController
        self.server = server
        self.pipelineId = pipelineId
        self.pipelineName = pipelineName
        self.audioRecorder = audioRecorder
        self.assistService = assistService ?? AssistService(server: server)
        super.init()
        self.audioRecorder.managesAudioSession = Current.settingsStore.carPlayAssistRecorderManagesAudioSession
        registerForAudioSessionNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func start() {
        audioRecorder.delegate = self
        assistService.delegate = self
        stateQueue.sync {
            state = .recording
            isStopped = false
            canSendAudioData = false
        }
        configureAudioSessionForAssist()
        activateVoiceControlState(for: .recording)
        interfaceController?.presentTemplate(template, animated: true, completion: nil)
        audioRecorder.startRecording()
    }

    func stop() {
        stop(dismissTemplate: true)
    }

    func templateWillDisappear(template disappearingTemplate: CPTemplate) {
        guard disappearingTemplate === template else { return }
        stop(dismissTemplate: false)
    }

    private func stop(dismissTemplate: Bool) {
        let alreadyStopped: Bool = stateQueue.sync {
            if isStopped { return true }
            isStopped = true
            canSendAudioData = false
            return false
        }
        guard !alreadyStopped else { return }
        audioRecorder.stopRecording()
        assistService.finishSendingAudio()
        ttsAudioPlayer?.stop()
        ttsAudioPlayer = nil
        ttsPlayer.pause()
        ttsPlayer.replaceCurrentItem(with: nil)
        clearTTSPlayerObservers()
        deactivateAudioSession()
        NotificationCenter.default.removeObserver(self)
        if dismissTemplate {
            interfaceController?.dismissTemplate(animated: true, completion: nil)
        }
        onStop?()
    }

    // MARK: - Audio Session

    private func configureAudioSessionForAssist() {
        do {
            try audioSession.setCategory(
                Current.settingsStore.carPlayAssistAudioCategory.avCategory,
                mode: Current.settingsStore.carPlayAssistAudioMode.avMode,
                options: makeAudioSessionOptions(
                    allowBluetoothHFP: Current.settingsStore.carPlayAssistAllowBluetoothHFP,
                    allowBluetoothA2DP: Current.settingsStore.carPlayAssistAllowBluetoothA2DP,
                    duckOthers: false,
                    interruptSpokenAudio: false
                )
            )
            try audioSession.setPreferredSampleRate(Current.settingsStore.carPlayAssistPreferredSampleRate.value)
            try audioSession.setActive(true)
            logCurrentAudioRoute(context: "activated")
        } catch {
            Current.Log.error("CarPlay Assist failed to configure audio session: \(error.localizedDescription)")
        }
    }

    private func configureAudioSessionForTTSIfNeeded() {
        guard Current.settingsStore.carPlayAssistTTSReconfigureAudioSession else { return }

        do {
            if Current.settingsStore.carPlayAssistTTSDeactivateBeforeReconfigure {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            }

            try audioSession.setCategory(
                Current.settingsStore.carPlayAssistTTSCategory.avCategory,
                mode: Current.settingsStore.carPlayAssistTTSMode.avMode,
                options: makeAudioSessionOptions(
                    allowBluetoothHFP: Current.settingsStore.carPlayAssistTTSAllowBluetoothHFP,
                    allowBluetoothA2DP: Current.settingsStore.carPlayAssistTTSAllowBluetoothA2DP,
                    duckOthers: Current.settingsStore.carPlayAssistTTSDuckOthers,
                    interruptSpokenAudio: Current.settingsStore.carPlayAssistTTSInterruptSpokenAudio
                )
            )

            if Current.settingsStore.carPlayAssistTTSActivateAudioSession {
                try audioSession.setActive(true)
            }

            logCurrentAudioRoute(context: "tts configured")
        } catch {
            Current.Log.error("CarPlay Assist failed to configure TTS audio session: \(error.localizedDescription)")
        }
    }

    private func makeAudioSessionOptions(
        allowBluetoothHFP: Bool,
        allowBluetoothA2DP: Bool,
        duckOthers: Bool,
        interruptSpokenAudio: Bool
    ) -> AVAudioSession.CategoryOptions {
        var options: AVAudioSession.CategoryOptions = []
        if allowBluetoothHFP {
            options.insert(.allowBluetoothHFP)
        }
        if allowBluetoothA2DP {
            options.insert(.allowBluetoothA2DP)
        }
        if duckOthers {
            options.insert(.duckOthers)
        }
        if interruptSpokenAudio {
            options.insert(.interruptSpokenAudioAndMixWithOthers)
        }
        return options
    }

    private func deactivateAudioSession() {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            Current.Log.error("CarPlay Assist failed to deactivate audio session: \(error.localizedDescription)")
        }
    }

    private func registerForAudioSessionNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: audioSession
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesWereReset),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: audioSession
        )
    }

    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            Current.Log.error("CarPlay Assist received audio interruption without a valid type")
            return
        }

        switch type {
        case .began:
            Current.Log.info("CarPlay Assist audio session interruption began")
            let stopped = stateQueue.sync { isStopped }
            guard !stopped else { return }
            stop()
        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            Current.Log
                .info(
                    "CarPlay Assist audio session interruption ended, shouldResume: \(options.contains(.shouldResume))"
                )
        @unknown default:
            Current.Log.info("CarPlay Assist audio session interruption ended with unknown type")
        }
    }

    @objc private func handleAudioSessionRouteChange(_ notification: Notification) {
        let reasonDescription: String
        if let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
           let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) {
            reasonDescription = String(describing: reason)
        } else {
            reasonDescription = "unknown"
        }

        Current.Log.info("CarPlay Assist audio route changed: \(reasonDescription)")
        logCurrentAudioRoute(context: "route change")
    }

    @objc private func handleMediaServicesWereReset() {
        let stopped = stateQueue.sync { isStopped }
        guard !stopped else { return }

        Current.Log.error("CarPlay Assist audio media services were reset")
        configureAudioSessionForAssist()
    }

    private func logCurrentAudioRoute(context: String) {
        let inputs = audioSession.currentRoute.inputs.map(\.portType.rawValue).joined(separator: ",")
        let outputs = audioSession.currentRoute.outputs.map(\.portType.rawValue).joined(separator: ",")
        Current.Log.info("CarPlay Assist audio route \(context). inputs: [\(inputs)] outputs: [\(outputs)]")
    }

    private func playRecordingIndicatorToneIfNeeded() {
        guard Current.settingsStore.carPlayAssistPlayRecordingIndicatorTone else { return }

        do {
            guard let toneURL = Bundle.main.url(
                forResource: "center_button_press",
                withExtension: "flac",
                subdirectory: "Sounds/Assist"
            ) else {
                Current.Log.error("CarPlay Assist could not find center_button_press.flac in the app bundle")
                AudioServicesPlaySystemSound(1113)
                return
            }

            recordingIndicatorPlayer = try AVAudioPlayer(contentsOf: toneURL)
            recordingIndicatorPlayer?.volume = 0.7
            recordingIndicatorPlayer?.prepareToPlay()
            recordingIndicatorPlayer?.play()
        } catch {
            Current.Log.error("CarPlay Assist failed to play recording indicator tone: \(error.localizedDescription)")
            AudioServicesPlaySystemSound(1113)
        }
    }

    // MARK: - TTS Playback

    /// Plays TTS audio using the already active conversational audio session to preserve the car route.
    private func playTTS(url: URL) {
        let playbackDelay = Current.settingsStore.carPlayAssistTTSPlaybackDelay.seconds
        if playbackDelay > 0 {
            Current.Log.info("CarPlay Assist delaying TTS playback by \(playbackDelay)s")
            DispatchQueue.main.asyncAfter(deadline: .now() + playbackDelay) { [weak self] in
                self?.startTTSPlayback(url: url)
            }
        } else {
            startTTSPlayback(url: url)
        }
    }

    private func startTTSPlayback(url: URL) {
        let stopped = stateQueue.sync { isStopped }
        guard !stopped else { return }

        configureAudioSessionForTTSIfNeeded()
        logCurrentAudioRoute(context: "before tts playback")

        switch Current.settingsStore.carPlayAssistTTSPlaybackStrategy {
        case .avPlayer:
            playTTSWithAVPlayer(url: url)
        case .downloadedAVAudioPlayer:
            playTTSWithDownloadedAudioPlayer(url: url)
        }
    }

    private func playTTSWithAVPlayer(url: URL) {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemPlaybackStalled, object: nil)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: nil)
        clearTTSPlayerObservers()

        let playerItem = AVPlayerItem(url: url)
        ttsPlayer.automaticallyWaitsToMinimizeStalling =
            Current.settingsStore.carPlayAssistAVPlayerAutomaticallyWaitsToMinimizeStalling
        ttsPlayer.replaceCurrentItem(with: playerItem)
        observeTTSPlayer(item: playerItem)
        Current.Log.info("CarPlay Assist starting AVPlayer TTS for URL: \(url.absoluteString)")
        ttsPlayer.play()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ttsDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ttsPlaybackStalled(_:)),
            name: .AVPlayerItemPlaybackStalled,
            object: playerItem
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ttsFailedToPlayToEnd(_:)),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem
        )
    }

    private func playTTSWithDownloadedAudioPlayer(url: URL) {
        Current.Log.info("CarPlay Assist downloading TTS audio for AVAudioPlayer: \(url.absoluteString)")

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }

            if let error {
                Current.Log.error("CarPlay Assist failed to download TTS audio: \(error.localizedDescription)")
                stop()
                return
            }

            guard let data else {
                Current.Log.error("CarPlay Assist downloaded empty TTS audio data")
                stop()
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let stopped = stateQueue.sync { self.isStopped }
                guard !stopped else { return }

                do {
                    ttsAudioPlayer = try AVAudioPlayer(data: data)
                    ttsAudioPlayer?.delegate = self
                    ttsAudioPlayer?.prepareToPlay()
                    if ttsAudioPlayer?.play() == true {
                        Current.Log.info("CarPlay Assist started downloaded AVAudioPlayer TTS playback")
                    } else {
                        Current.Log.error("CarPlay Assist AVAudioPlayer failed to start TTS playback")
                        stop()
                    }
                } catch {
                    Current.Log
                        .error("CarPlay Assist failed to create AVAudioPlayer for TTS: \(error.localizedDescription)")
                    stop()
                }
            }
        }.resume()
    }

    private func observeTTSPlayer(item: AVPlayerItem) {
        ttsPlayerItemStatusObservation = item.observe(\.status, options: [.initial, .new]) { item, _ in
            switch item.status {
            case .unknown:
                Current.Log.info("CarPlay Assist TTS player item status: unknown")
            case .readyToPlay:
                Current.Log.info("CarPlay Assist TTS player item status: readyToPlay")
            case .failed:
                Current.Log.error(
                    "CarPlay Assist TTS player item failed: \(item.error?.localizedDescription ?? "unknown error")"
                )
            @unknown default:
                Current.Log.info("CarPlay Assist TTS player item status: unknown future case")
            }
        }

        ttsPlayerTimeControlObservation = ttsPlayer.observe(\.timeControlStatus, options: [
            .initial,
            .new,
        ]) { player, _ in
            let description: String
            switch player.timeControlStatus {
            case .paused:
                description = "paused"
            case .waitingToPlayAtSpecifiedRate:
                description = "waiting"
            case .playing:
                description = "playing"
            @unknown default:
                description = "unknown"
            }
            Current.Log.info("CarPlay Assist TTS player timeControlStatus: \(description)")
        }
    }

    private func clearTTSPlayerObservers() {
        ttsPlayerItemStatusObservation = nil
        ttsPlayerTimeControlObservation = nil
    }

    @objc private func ttsPlaybackStalled(_ notification: Notification) {
        Current.Log.error("CarPlay Assist TTS playback stalled")
    }

    @objc private func ttsFailedToPlayToEnd(_ notification: Notification) {
        let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
        Current.Log.error("CarPlay Assist TTS failed to play to end: \(error?.localizedDescription ?? "unknown error")")
    }

    @objc private func ttsDidFinishPlaying(_ notification: Notification) {
        let stopped = stateQueue.sync { isStopped }
        guard !stopped else { return }
        if assistService.shouldStartListeningAgainAfterPlaybackEnd {
            assistService.resetShouldStartListeningAgainAfterPlaybackEnd()
            restartRecording()
        } else {
            enterIdleState()
        }
    }

    // MARK: - Voice Control State Updates

    private func activateVoiceControlState(for state: State) {
        let identifier: String
        switch state {
        case .idle:
            identifier = VoiceControlStateID.idle.rawValue
        case .recording:
            identifier = VoiceControlStateID.recording.rawValue
        case .processing:
            identifier = VoiceControlStateID.processing.rawValue
        case .responding:
            identifier = VoiceControlStateID.responding.rawValue
        case .error:
            return
        }
        if Thread.isMainThread {
            template.activateVoiceControlState(withIdentifier: identifier)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.template.activateVoiceControlState(withIdentifier: identifier)
            }
        }
    }

    private func restartRecording() {
        stateQueue.sync {
            canSendAudioData = false
            state = .recording
        }
        ttsAudioPlayer?.stop()
        ttsAudioPlayer = nil
        ttsPlayer.pause()
        ttsPlayer.replaceCurrentItem(with: nil)
        clearTTSPlayerObservers()
        configureAudioSessionForAssist()
        activateVoiceControlState(for: .recording)
        audioRecorder.startRecording()
    }

    private func enterIdleState() {
        stateQueue.sync {
            canSendAudioData = false
            state = .idle
        }
        ttsAudioPlayer?.stop()
        ttsAudioPlayer = nil
        ttsPlayer.pause()
        ttsPlayer.replaceCurrentItem(with: nil)
        clearTTSPlayerObservers()
        deactivateAudioSession()
        activateVoiceControlState(for: .idle)
    }
}

// MARK: - AudioRecorderDelegate

@available(iOS 26.4, *)
extension CarPlayAssistSession: AudioRecorderDelegate {
    func didStartRecording(with sampleRate: Double) {
        playRecordingIndicatorToneIfNeeded()
        assistService.assist(source: .audio(
            pipelineId: pipelineId,
            audioSampleRate: sampleRate,
            tts: true
        ))
    }

    func didOutputSample(data: Data) {
        let canSend = stateQueue.sync { canSendAudioData && !isStopped }
        guard canSend else { return }
        assistService.sendAudioData(data)
    }

    func didStopRecording() {
        // Recording stopped, waiting for server processing
    }

    func didFailToRecord(error: any Error) {
        let shouldHandle: Bool = stateQueue.sync {
            guard !isStopped, !state.isError else { return false }
            state = .error(error.localizedDescription)
            return true
        }
        guard shouldHandle else { return }
        Current.Log.error("CarPlay Assist recording failed: \(error.localizedDescription)")
        stop()
    }
}

@available(iOS 26.4, *)
extension CarPlayAssistSession: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Current.Log.info("CarPlay Assist AVAudioPlayer TTS finished, success: \(flag)")
        let stopped = stateQueue.sync { isStopped }
        guard !stopped else { return }

        if assistService.shouldStartListeningAgainAfterPlaybackEnd {
            assistService.resetShouldStartListeningAgainAfterPlaybackEnd()
            restartRecording()
        } else {
            enterIdleState()
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Current.Log
            .error("CarPlay Assist AVAudioPlayer decode error: \(error?.localizedDescription ?? "unknown error")")
        stop()
    }
}

@available(iOS 26.4, *)
private extension CarPlayAssistSession {
    static let recordingIndicatorToneData: Data = {
        let sampleRate = 24000
        let duration = 0.12
        let frequency = 880.0
        let frameCount = Int(Double(sampleRate) * duration)
        let amplitude = 0.25

        var pcmData = Data(capacity: frameCount * MemoryLayout<Int16>.size)

        for frame in 0 ..< frameCount {
            let progress = Double(frame) / Double(frameCount)
            let envelope = min(progress / 0.1, (1.0 - progress) / 0.15, 1.0)
            let sample = sin(2.0 * .pi * frequency * progress * duration) * amplitude * envelope
            let intSample = Int16(max(-1.0, min(1.0, sample)) * Double(Int16.max))
            var littleEndianSample = intSample.littleEndian
            pcmData.append(Data(bytes: &littleEndianSample, count: MemoryLayout<Int16>.size))
        }

        let bytesPerSample = MemoryLayout<Int16>.size
        let subchunk2Size = frameCount * bytesPerSample
        let chunkSize = 36 + subchunk2Size
        let byteRate = sampleRate * bytesPerSample
        let blockAlign = UInt16(bytesPerSample)
        let bitsPerSample: UInt16 = 16
        let channels: UInt16 = 1
        let audioFormat: UInt16 = 1

        func littleEndianData<T: FixedWidthInteger>(_ value: T) -> Data {
            var littleEndian = value.littleEndian
            return Data(bytes: &littleEndian, count: MemoryLayout<T>.size)
        }

        var wavData = Data()
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(littleEndianData(UInt32(chunkSize)))
        wavData.append("WAVE".data(using: .ascii)!)
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(littleEndianData(UInt32(16)))
        wavData.append(littleEndianData(audioFormat))
        wavData.append(littleEndianData(channels))
        wavData.append(littleEndianData(UInt32(sampleRate)))
        wavData.append(littleEndianData(UInt32(byteRate)))
        wavData.append(littleEndianData(blockAlign))
        wavData.append(littleEndianData(bitsPerSample))
        wavData.append("data".data(using: .ascii)!)
        wavData.append(littleEndianData(UInt32(subchunk2Size)))
        wavData.append(pcmData)
        return wavData
    }()
}

// MARK: - AssistServiceDelegate

@available(iOS 26.4, *)
extension CarPlayAssistSession: AssistServiceDelegate {
    func didReceiveGreenLightForAudioInput() {
        stateQueue.sync { canSendAudioData = true }
    }

    func didReceiveEvent(_ event: AssistEvent) {
        if event == .sttEnd {
            let shouldHandleSttEnd = stateQueue.sync { () -> Bool in
                guard !isStopped else { return false }
                canSendAudioData = false
                state = .processing
                return true
            }
            guard shouldHandleSttEnd else { return }
            audioRecorder.stopRecording()
            assistService.finishSendingAudio()
            activateVoiceControlState(for: .processing)
        }
    }

    func didReceiveSttContent(_ content: String) {
        // No text display in CarPlay
    }

    func didReceiveStreamResponseChunk(_ content: String) {
        // No text display in CarPlay
    }

    func didReceiveIntentEndContent(_ content: String) {
        let stopped = stateQueue.sync { isStopped }
        guard !stopped else { return }
        stateQueue.sync { state = .responding }
        activateVoiceControlState(for: .responding)
    }

    func didReceiveTtsMediaUrl(_ mediaUrl: URL) {
        let stopped = stateQueue.sync { isStopped }
        guard !stopped else { return }
        playTTS(url: mediaUrl)
    }

    func didReceiveError(code: String, message: String) {
        let stopped = stateQueue.sync { isStopped }
        guard !stopped else { return }
        Current.Log.error("CarPlay Assist error [\(code)]: \(message)")
        stateQueue.sync { state = .error(message) }
        stop()
    }
}
