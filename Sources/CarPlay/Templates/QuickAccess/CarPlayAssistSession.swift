import AVFoundation
import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 26.4, *)
final class CarPlayAssistSession: NSObject {
    typealias OnStop = () -> Void

    enum State: Equatable {
        case idle
        case recording
        case processing
        case responding
        case error(String)

        var isError: Bool {
            if case .error = self { return true }
            return false
        }

        /// States where the session is waiting on further pipeline events from the server.
        var isAwaitingPipelineResponse: Bool {
            switch self {
            case .processing, .responding: return true
            case .idle, .recording, .error: return false
            }
        }

        var isRecording: Bool {
            if case .recording = self { return true }
            return false
        }
    }

    private enum VoiceControlStateID: String {
        case idle
        case recording
        case processing
        case responding
        case error
    }

    weak var interfaceController: CPInterfaceController?
    var onStop: OnStop?

    private let audioSession = AVAudioSession.sharedInstance()
    private let tonePlayer: CarPlayAssistTonePlayerProtocol
    private var assistService: AssistServiceProtocol
    private var audioRecorder: AudioRecorderProtocol

    /// Assist settings shared globally with the in-app Assist via the `AssistConfiguration`
    /// database singleton: mute TTS, on-device STT/TTS and their locale/voice. CarPlay owns
    /// the audio session for the whole conversation, so the on-device speech components run
    /// with `managesAudioSession = false`.
    private var assistConfiguration = AssistConfiguration()
    /// Configuration override from the initializer; when nil, `start()` reads the database.
    private let injectedAssistConfiguration: AssistConfiguration?
    private var speechTranscriber: (any SpeechTranscriberProtocol)?
    private var speechSynthesizer: (any SpeechSynthesizerProtocol)?
    /// True while an on-device transcription started by this session is listening; used to tell
    /// a no-speech stop apart from stops the session itself requested.
    private var onDeviceListeningActive = false
    private var ttsAudioPlayer: AVAudioPlayer?
    private let ttsPlayer = AVPlayer()
    private var ttsPlayerItemStatusObservation: NSKeyValueObservation?
    private var ttsPlayerTimeControlObservation: NSKeyValueObservation?
    /// Detects AVPlayer TTS playback that never starts (e.g. unreachable media URL) so it can
    /// fall back to downloading the clip instead of failing silently.
    private var ttsStartWatchdog: DispatchWorkItem?
    private var ttsPlaybackDidStart = false
    private static let ttsStartTimeout: TimeInterval = 5

    /// Detects a pipeline run that goes quiet before delivering a response (e.g. the WebSocket
    /// subscription dying mid-run) so the session shows the error state instead of spinning on
    /// "Processing" forever. Re-armed on every pipeline event, so slow-but-alive runs
    /// (LLM streaming) are not cut off. Both properties are protected by `stateQueue`.
    private var responseWatchdog: DispatchWorkItem?
    private var ttsWasRequested = false
    private static let responseTimeout: TimeInterval = 30

    /// Serial queue protecting all mutable session state (`canSendAudioData`, `state`, `isStopped`,
    /// `ttsWasRequested`, `responseWatchdog`).
    /// Callbacks from AVCaptureSession, HAKit, and NotificationCenter may arrive on arbitrary threads.
    private let stateQueue = DispatchQueue(label: "io.home-assistant.carplay-assist-session", qos: .userInteractive)
    private var canSendAudioData = false
    private var state: State = .recording
    private var isStopped = false
    private var postDismissAction: (() -> Void)?

    private let pipelineId: String
    private let prompt: String?

    private lazy var template: CPVoiceControlTemplate = {
        let recordButton = CPButton(
            image: makeActionButtonImage(icon: .microphoneIcon, color: .haPrimary)
        ) { [weak self] _ in
            self?.restartRecording()
        }
        let replayPromptButton = CPButton(
            image: makeActionButtonImage(icon: .replayIcon, color: .haPrimary)
        ) { [weak self] _ in
            self?.restartPrompt()
        }
        let helpButton = CPButton(
            image: makeActionButtonImage(icon: .commentQuestionIcon, color: .gray)
        ) { [weak self] _ in
            self?.showPlaybackHelp()
        }

        let actionButtons: [CPButton] = promptToSend == nil
            ? [recordButton, helpButton]
            : [recordButton, replayPromptButton, helpButton]

        let idleState = CPVoiceControlState(
            identifier: VoiceControlStateID.idle.rawValue,
            titleVariants: [L10n.Assist.Carplay.TapToRecord.title],
            image: MaterialDesignIcons.messageProcessingOutlineIcon.carPlayIcon(
                color: .haPrimary,
                context: .assistStateIndicator
            ),
            repeats: false
        )
        idleState.actionButtons = actionButtons

        let recordingState = CPVoiceControlState(
            identifier: VoiceControlStateID.recording.rawValue,
            titleVariants: [L10n.Assist.Button.Listening.title],
            image: MaterialDesignIcons.microphoneIcon.carPlayIcon(color: .haPrimary, context: .assistStateIndicator),
            repeats: true
        )
        let processingState = CPVoiceControlState(
            identifier: VoiceControlStateID.processing.rawValue,
            titleVariants: [L10n.Assist.Carplay.Processing.title],
            image: MaterialDesignIcons.dotsHorizontalIcon.carPlayIcon(
                color: .haPrimary,
                context: .assistStateIndicator
            ),
            repeats: true
        )
        let respondingState = CPVoiceControlState(
            identifier: VoiceControlStateID.responding.rawValue,
            titleVariants: [L10n.Assist.Carplay.Responding.title],
            image: MaterialDesignIcons.volumeHighIcon.carPlayIcon(color: .haPrimary, context: .assistStateIndicator),
            repeats: true
        )
        let errorState = CPVoiceControlState(
            identifier: VoiceControlStateID.error.rawValue,
            titleVariants: [L10n.errorLabel],
            image: MaterialDesignIcons.alertCircleIcon.carPlayIcon(color: .systemRed, context: .assistStateIndicator),
            repeats: false
        )
        errorState.actionButtons = actionButtons

        return CPVoiceControlTemplate(
            voiceControlStates: [recordingState, processingState, respondingState, idleState, errorState]
        )
    }()

    init(
        interfaceController: CPInterfaceController?,
        server: Server,
        pipelineId: String,
        prompt: String? = nil,
        audioRecorder: AudioRecorderProtocol = AudioRecorder(),
        assistService: AssistServiceProtocol? = nil,
        assistConfiguration: AssistConfiguration? = nil,
        speechTranscriber: (any SpeechTranscriberProtocol)? = nil,
        speechSynthesizer: (any SpeechSynthesizerProtocol)? = nil,
        tonePlayer: CarPlayAssistTonePlayerProtocol = CarPlayAssistTonePlayer()
    ) {
        self.interfaceController = interfaceController
        self.pipelineId = pipelineId
        self.prompt = prompt
        self.audioRecorder = audioRecorder
        self.assistService = assistService ?? AssistService(server: server)
        self.injectedAssistConfiguration = assistConfiguration
        self.speechTranscriber = speechTranscriber
        self.speechSynthesizer = speechSynthesizer
        self.tonePlayer = tonePlayer
        super.init()
        self.audioRecorder.managesAudioSession = Current.settingsStore.carPlayAssistDebugSettings
            .recorderManagesAudioSession
        registerForAudioSessionNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Snapshot of the current session state, for unit tests.
    var currentState: State {
        stateQueue.sync { state }
    }

    func start() {
        assistConfiguration = injectedAssistConfiguration ?? AssistConfiguration.config
        assistService.delegate = self
        stateQueue.sync {
            isStopped = false
            canSendAudioData = false
        }

        if let promptToSend {
            startPrompt(promptToSend, presentTemplate: true)
        } else {
            startRecording(presentTemplate: true)
        }
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
        cancelResponseWatchdog()
        audioRecorder.stopRecording()
        stopOnDeviceSpeech()
        assistService.finishSendingAudio()
        tonePlayer.stop()
        ttsAudioPlayer?.stop()
        ttsAudioPlayer = nil
        ttsPlayer.pause()
        ttsPlayer.replaceCurrentItem(with: nil)
        clearTTSPlayerObservers()
        deactivateAudioSession()
        NotificationCenter.default.removeObserver(self)
        if dismissTemplate {
            interfaceController?.dismissTemplate(animated: true, completion: { [weak self] _, error in
                if let error {
                    Current.Log.error("CarPlay Assist failed to dismiss template: \(error.localizedDescription)")
                }

                let postDismissAction = self?.postDismissAction
                self?.postDismissAction = nil
                postDismissAction?()
                self?.onStop?()
            })
        } else {
            postDismissAction = nil
            onStop?()
        }
    }

    private func showPlaybackHelp() {
        postDismissAction = { [weak self] in
            self?.presentPlaybackHelpTemplate()
        }
        stop()
    }

    private func presentPlaybackHelpTemplate() {
        let template = CPInformationTemplate(
            title: L10n.Assist.Carplay.PlaybackHelp.title,
            layout: .leading,
            items: [
                CPInformationItem(
                    title: L10n.Assist.Carplay.PlaybackHelp.OpenApp.title,
                    detail: L10n.Assist.Carplay.PlaybackHelp.OpenApp.detail
                ),
                CPInformationItem(
                    title: L10n.Assist.Carplay.PlaybackHelp.GoToTroubleshooting.title,
                    detail: L10n.Assist.Carplay.PlaybackHelp.GoToTroubleshooting.detail
                ),
                CPInformationItem(
                    title: L10n.Assist.Carplay.PlaybackHelp.ChangePlayback.title,
                    detail: L10n.Assist.Carplay.PlaybackHelp.ChangePlayback.detail
                ),
            ],
            actions: []
        )
        interfaceController?.pushTemplate(template, animated: true, completion: { _, error in
            if let error {
                Current.Log.error("CarPlay Assist failed to present playback help: \(error.localizedDescription)")
            }
        })
    }

    private func makeActionButtonImage(
        icon: MaterialDesignIcons,
        color: UIColor
    ) -> UIImage {
        let iconScale: CGFloat = 0.42
        let canvasSize = CPButtonMaximumImageSize
        let iconSize = CGSize(
            width: canvasSize.width * iconScale,
            height: canvasSize.height * iconScale
        )
        let iconImage = icon.image(ofSize: iconSize, color: color)
        let iconOrigin = CGPoint(
            x: (canvasSize.width - iconSize.width) / 2,
            y: (canvasSize.height - iconSize.height) / 2
        )

        return UIGraphicsImageRenderer(
            size: canvasSize,
            format: with(UIGraphicsImageRendererFormat.preferred()) {
                $0.opaque = false
            }
        ).image { _ in
            iconImage.draw(in: CGRect(origin: iconOrigin, size: iconSize))
        }
    }

    /// Server TTS is only requested when responses are not muted and not spoken on device.
    private var shouldRequestServerTTS: Bool {
        !assistConfiguration.muteTTS && !assistConfiguration.enableOnDeviceTTS
    }

    private var promptToSend: String? {
        guard let prompt = prompt?.trimmingCharacters(in: .whitespacesAndNewlines), !prompt.isEmpty else {
            return nil
        }

        return prompt
    }

    private func startRecording(presentTemplate: Bool) {
        stateQueue.sync {
            canSendAudioData = false
            state = .recording
            ttsWasRequested = false
        }
        cancelResponseWatchdog()
        configureAudioSessionForAssist()
        activateVoiceControlState(for: .recording)
        if presentTemplate {
            interfaceController?.presentTemplate(template, animated: true, completion: nil)
        }
        if assistConfiguration.enableOnDeviceSTT {
            startOnDeviceTranscription()
        } else {
            audioRecorder.delegate = self
            audioRecorder.startRecording()
        }
    }

    private func startPrompt(_ prompt: String, presentTemplate: Bool) {
        stateQueue.sync {
            canSendAudioData = false
            state = .processing
            ttsWasRequested = false
        }
        ttsAudioPlayer?.stop()
        ttsAudioPlayer = nil
        ttsPlayer.pause()
        ttsPlayer.replaceCurrentItem(with: nil)
        clearTTSPlayerObservers()
        configureAudioSessionForAssist()
        activateVoiceControlState(for: .processing)
        if presentTemplate {
            interfaceController?.presentTemplate(template, animated: true, completion: nil)
        }
        playProcessingIndicatorToneIfNeeded()
        assistService.assist(source: .text(
            input: prompt,
            pipelineId: pipelineId,
            expectTTS: shouldRequestServerTTS
        ))
        armResponseWatchdog()
    }

    // MARK: - Audio Session

    private func configureAudioSessionForAssist() {
        let settings = Current.settingsStore.carPlayAssistDebugSettings
        do {
            try audioSession.setCategory(
                settings.audioCategory.avCategory,
                mode: settings.audioMode.avMode,
                options: makeAudioSessionOptions(
                    category: settings.audioCategory.avCategory,
                    allowBluetoothHFP: settings.allowBluetoothHFP,
                    allowBluetoothA2DP: settings.allowBluetoothA2DP,
                    duckOthers: settings.duckOthers,
                    interruptSpokenAudio: settings.interruptSpokenAudio
                )
            )
            try audioSession.setPreferredSampleRate(settings.preferredSampleRate.value)
            try audioSession.setActive(true)
            logCurrentAudioRoute(context: "activated")
        } catch {
            Current.Log.error("CarPlay Assist failed to configure audio session: \(error.localizedDescription)")
        }
    }

    private func configureAudioSessionForTTSIfNeeded() {
        let settings = Current.settingsStore.carPlayAssistDebugSettings
        guard settings.ttsReconfigureAudioSession else { return }

        do {
            if settings.ttsDeactivateBeforeReconfigure {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            }

            try audioSession.setCategory(
                settings.ttsCategory.avCategory,
                mode: settings.ttsMode.avMode,
                options: makeAudioSessionOptions(
                    category: settings.ttsCategory.avCategory,
                    allowBluetoothHFP: settings.ttsAllowBluetoothHFP,
                    allowBluetoothA2DP: settings.ttsAllowBluetoothA2DP,
                    duckOthers: settings.ttsDuckOthers,
                    interruptSpokenAudio: settings.ttsInterruptSpokenAudio
                )
            )

            if settings.ttsActivateAudioSession {
                try audioSession.setActive(true)
            }

            logCurrentAudioRoute(context: "tts configured")
        } catch {
            Current.Log.error("CarPlay Assist failed to configure TTS audio session: \(error.localizedDescription)")
        }
    }

    private func makeAudioSessionOptions(
        category: AVAudioSession.Category,
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
        // Only valid with .playAndRecord: without it, playback with no car/Bluetooth route
        // defaults to the receiver (earpiece) and Assist audio is nearly inaudible.
        if category == .playAndRecord {
            options.insert(.defaultToSpeaker)
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

    // Tones go through the audio session (not the system sound server) so they stay audible
    // when the iPhone ring/silent switch is muted, like any other media playback.
    private func playRecordingIndicatorToneIfNeeded() {
        guard Current.settingsStore.carPlayAssistDebugSettings.playRecordingIndicatorTone else { return }
        tonePlayer.play(.startRecording)
    }

    private func playProcessingIndicatorToneIfNeeded() {
        tonePlayer.play(.processing)
    }

    // MARK: - TTS Playback

    /// Plays TTS audio using the already active conversational audio session to preserve the car route.
    private func playTTS(url: URL) {
        let playbackDelay = Current.settingsStore.carPlayAssistDebugSettings.ttsPlaybackDelay.seconds
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

        switch Current.settingsStore.carPlayAssistDebugSettings.ttsPlaybackStrategy {
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
        ttsPlayer.automaticallyWaitsToMinimizeStalling = Current.settingsStore
            .carPlayAssistDebugSettings
            .avPlayerAutomaticallyWaitsToMinimizeStalling
        ttsPlayer.replaceCurrentItem(with: playerItem)
        observeTTSPlayer(item: playerItem, url: url)
        Current.Log.info("CarPlay Assist starting AVPlayer TTS for URL: \(url.absoluteString)")
        ttsPlaybackDidStart = false
        ttsPlayer.play()
        scheduleTTSStartWatchdog(url: url)

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
                enterErrorState(message: error.localizedDescription)
                return
            }

            guard let data else {
                Current.Log.error("CarPlay Assist downloaded empty TTS audio data")
                enterErrorState(message: "Downloaded empty TTS audio data")
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
                        enterErrorState(message: "AVAudioPlayer failed to start TTS playback")
                    }
                } catch {
                    Current.Log
                        .error("CarPlay Assist failed to create AVAudioPlayer for TTS: \(error.localizedDescription)")
                    enterErrorState(message: error.localizedDescription)
                }
            }
        }.resume()
    }

    private func observeTTSPlayer(item: AVPlayerItem, url: URL) {
        ttsPlayerItemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            switch item.status {
            case .unknown:
                Current.Log.info("CarPlay Assist TTS player item status: unknown")
            case .readyToPlay:
                Current.Log.info("CarPlay Assist TTS player item status: readyToPlay")
            case .failed:
                Current.Log.error(
                    "CarPlay Assist TTS player item failed: \(item.error?.localizedDescription ?? "unknown error")"
                )
                self?.fallBackToDownloadedTTS(url: url)
            @unknown default:
                Current.Log.info("CarPlay Assist TTS player item status: unknown future case")
            }
        }

        ttsPlayerTimeControlObservation = ttsPlayer.observe(\.timeControlStatus, options: [
            .initial,
            .new,
        ]) { [weak self] player, _ in
            let description: String
            switch player.timeControlStatus {
            case .paused:
                description = "paused"
            case .waitingToPlayAtSpecifiedRate:
                description = "waiting"
            case .playing:
                description = "playing"
                self?.ttsPlaybackDidStart = true
                self?.ttsStartWatchdog?.cancel()
            @unknown default:
                description = "unknown"
            }
            Current.Log.info("CarPlay Assist TTS player timeControlStatus: \(description)")
        }
    }

    private func clearTTSPlayerObservers() {
        ttsPlayerItemStatusObservation = nil
        ttsPlayerTimeControlObservation = nil
        ttsStartWatchdog?.cancel()
        ttsStartWatchdog = nil
    }

    private func scheduleTTSStartWatchdog(url: URL) {
        ttsStartWatchdog?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard ttsPlayer.timeControlStatus != .playing else { return }
            Current.Log.error(
                "CarPlay Assist AVPlayer TTS did not start within \(Self.ttsStartTimeout)s"
            )
            fallBackToDownloadedTTS(url: url)
        }
        ttsStartWatchdog = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.ttsStartTimeout, execute: workItem)
    }

    // MARK: - Response Watchdog

    private func armResponseWatchdog() {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let shouldFire = stateQueue.sync {
                !isStopped && state.isAwaitingPipelineResponse && !ttsWasRequested
            }
            guard shouldFire else { return }
            enterErrorState(message: "No response from the Assist pipeline within \(Self.responseTimeout)s")
        }
        stateQueue.sync {
            responseWatchdog?.cancel()
            responseWatchdog = workItem
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.responseTimeout, execute: workItem)
    }

    private func cancelResponseWatchdog() {
        stateQueue.sync {
            responseWatchdog?.cancel()
            responseWatchdog = nil
        }
    }

    /// AVPlayer TTS failed or never started; retry once by downloading the clip and playing it
    /// with AVAudioPlayer so the user hears either the response or the error tone, never silence.
    /// Failures after playback started are handled by `ttsFailedToPlayToEnd` instead.
    private func fallBackToDownloadedTTS(url: URL) {
        guard !ttsPlaybackDidStart else { return }
        clearTTSPlayerObservers()
        let stopped = stateQueue.sync { isStopped }
        guard !stopped else { return }
        Current.Log.info("CarPlay Assist falling back to downloaded TTS playback for URL: \(url.absoluteString)")
        ttsPlayer.pause()
        ttsPlayer.replaceCurrentItem(with: nil)
        playTTSWithDownloadedAudioPlayer(url: url)
    }

    @objc private func ttsPlaybackStalled(_ notification: Notification) {
        Current.Log.error("CarPlay Assist TTS playback stalled")
        enterErrorState(message: "TTS playback stalled")
    }

    @objc private func ttsFailedToPlayToEnd(_ notification: Notification) {
        let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
        Current.Log.error("CarPlay Assist TTS failed to play to end: \(error?.localizedDescription ?? "unknown error")")
        enterErrorState(message: error?.localizedDescription ?? "TTS failed to play to end")
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

    // MARK: - On-Device Speech (STT/TTS)

    private func startOnDeviceTranscription() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let transcriber = ensureSpeechTranscriber()
            onDeviceListeningActive = false
            do {
                try await transcriber.startListening()
                onDeviceListeningActive = true
                playRecordingIndicatorToneIfNeeded()
            } catch {
                Current.Log
                    .error("CarPlay Assist failed to start on-device transcription: \(error.localizedDescription)")
                enterErrorState(message: error.localizedDescription)
            }
        }
    }

    /// Returns the transcriber (injected or lazily created) with the session's callbacks
    /// installed. Callbacks are (re)assigned on every call so injected instances get them too.
    @MainActor private func ensureSpeechTranscriber() -> any SpeechTranscriberProtocol {
        let transcriber: any SpeechTranscriberProtocol
        if let speechTranscriber {
            transcriber = speechTranscriber
        } else {
            transcriber = assistConfiguration.onDeviceSTTLocaleIdentifier
                .map { SpeechTranscriber(localeIdentifier: $0) } ?? SpeechTranscriber()
            speechTranscriber = transcriber
        }
        transcriber.managesAudioSession = false
        transcriber.onTranscriptUpdate = { [weak self] text, isFinal in
            guard isFinal else { return }
            self?.handleOnDeviceFinalTranscript(text)
        }
        transcriber.onError = { [weak self] error in
            guard let self else { return }
            onDeviceListeningActive = false
            let wasRecording = stateQueue.sync { !isStopped && state.isRecording }
            guard wasRecording else { return }
            Current.Log.error("CarPlay Assist on-device transcription failed: \(error.localizedDescription)")
            enterErrorState(message: error.localizedDescription)
        }
        transcriber.onListeningStateChange = { [weak self] listening in
            guard let self, !listening else { return }
            guard onDeviceListeningActive else { return }
            onDeviceListeningActive = false
            // A final transcript switches the state to .processing before listening stops, so a
            // stop that leaves the state at .recording means nothing was recognized.
            let noSpeech = stateQueue.sync { !isStopped && state.isRecording }
            if noSpeech {
                enterErrorState(message: "No speech was recognized")
            }
        }
        return transcriber
    }

    private func handleOnDeviceFinalTranscript(_ text: String) {
        onDeviceListeningActive = false
        let shouldHandle = stateQueue.sync { () -> Bool in
            guard !isStopped, state.isRecording else { return false }
            canSendAudioData = false
            state = .processing
            ttsWasRequested = false
            return true
        }
        guard shouldHandle else { return }

        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            enterErrorState(message: "No speech was recognized")
            return
        }

        playProcessingIndicatorToneIfNeeded()
        activateVoiceControlState(for: .processing)
        assistService.assist(source: .text(
            input: input,
            pipelineId: pipelineId,
            expectTTS: shouldRequestServerTTS
        ))
        armResponseWatchdog()
    }

    private func speakOnDevice(_ content: String) {
        stateQueue.sync { ttsWasRequested = true }
        cancelResponseWatchdog()

        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            finishResponse()
            return
        }
        ensureSpeechSynthesizer().speak(text)
    }

    /// Returns the synthesizer (injected or lazily created) with the session's callbacks
    /// installed. Callbacks are (re)assigned on every call so injected instances get them too.
    private func ensureSpeechSynthesizer() -> any SpeechSynthesizerProtocol {
        let synthesizer: any SpeechSynthesizerProtocol
        if let speechSynthesizer {
            synthesizer = speechSynthesizer
        } else {
            synthesizer = assistConfiguration.onDeviceTTSVoiceIdentifier
                .map { SpeechSynthesizer(voiceIdentifier: $0) } ?? SpeechSynthesizer()
            speechSynthesizer = synthesizer
        }
        synthesizer.managesAudioSession = false
        synthesizer.onFinished = { [weak self] in
            self?.finishResponse()
        }
        return synthesizer
    }

    /// Ends a response that produces no further audio (on-device speech finished, muted, or
    /// empty content): starts listening again for a continued conversation, otherwise idles.
    private func finishResponse() {
        let stopped = stateQueue.sync { isStopped }
        guard !stopped else { return }
        if assistService.shouldStartListeningAgainAfterPlaybackEnd {
            assistService.resetShouldStartListeningAgainAfterPlaybackEnd()
            restartRecording()
        } else {
            enterIdleState()
        }
    }

    private func stopOnDeviceSpeech() {
        onDeviceListeningActive = false
        speechSynthesizer?.stop()
        if let speechTranscriber {
            Task { @MainActor in
                speechTranscriber.stopListening()
            }
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
            identifier = VoiceControlStateID.error.rawValue
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
        tonePlayer.stop()
        stopOnDeviceSpeech()
        ttsAudioPlayer?.stop()
        ttsAudioPlayer = nil
        ttsPlayer.pause()
        ttsPlayer.replaceCurrentItem(with: nil)
        clearTTSPlayerObservers()
        startRecording(presentTemplate: false)
    }

    private func restartPrompt() {
        guard let promptToSend else {
            restartRecording()
            return
        }
        tonePlayer.stop()
        stopOnDeviceSpeech()
        ttsAudioPlayer?.stop()
        ttsAudioPlayer = nil
        ttsPlayer.pause()
        ttsPlayer.replaceCurrentItem(with: nil)
        clearTTSPlayerObservers()
        startPrompt(promptToSend, presentTemplate: false)
    }

    private func enterIdleState() {
        stateQueue.sync {
            canSendAudioData = false
            state = .idle
        }
        cancelResponseWatchdog()
        stopOnDeviceSpeech()
        ttsAudioPlayer?.stop()
        ttsAudioPlayer = nil
        ttsPlayer.pause()
        ttsPlayer.replaceCurrentItem(with: nil)
        clearTTSPlayerObservers()
        deactivateAudioSession()
        activateVoiceControlState(for: .idle)
    }

    private func enterErrorState(message: String) {
        let shouldHandle = stateQueue.sync { () -> Bool in
            guard !isStopped else { return false }
            canSendAudioData = false
            state = .error(message)
            return true
        }
        guard shouldHandle else { return }

        cancelResponseWatchdog()
        stopOnDeviceSpeech()
        ttsAudioPlayer?.stop()
        ttsAudioPlayer = nil
        ttsPlayer.pause()
        ttsPlayer.replaceCurrentItem(with: nil)
        clearTTSPlayerObservers()
        Current.Log.error("CarPlay Assist entered error state: \(message)")
        // The audio session must stay active until the error tone finishes, otherwise the
        // tone is cut off; it is released once playback completes.
        tonePlayer.play(.error) { [weak self] in
            self?.deactivateAudioSession()
        }
        activateVoiceControlState(for: .error(message))
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
            tts: shouldRequestServerTTS
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
        enterErrorState(message: error.localizedDescription)
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
        enterErrorState(message: error?.localizedDescription ?? "AVAudioPlayer decode error")
    }
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
            playProcessingIndicatorToneIfNeeded()
            activateVoiceControlState(for: .processing)
            armResponseWatchdog()
        } else {
            // Every pipeline event proves the run is still alive, so push the deadline out.
            let awaitingResponse = stateQueue.sync {
                !isStopped && state.isAwaitingPipelineResponse && !ttsWasRequested
            }
            if awaitingResponse {
                armResponseWatchdog()
            }
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
        if assistConfiguration.muteTTS {
            // Voice responses are muted globally, so no audio follows; finish the run now.
            finishResponse()
        } else if assistConfiguration.enableOnDeviceTTS {
            speakOnDevice(content)
        }
    }

    func didReceiveTtsMediaUrl(_ mediaUrl: URL) {
        let shouldHandle = stateQueue.sync { () -> Bool in
            guard !isStopped else { return false }
            ttsWasRequested = true
            return true
        }
        guard shouldHandle else { return }
        cancelResponseWatchdog()
        playTTS(url: mediaUrl)
    }

    func didReceiveError(code: String, message: String) {
        let stopped = stateQueue.sync { isStopped }
        guard !stopped else { return }
        Current.Log.error("CarPlay Assist error [\(code)]: \(message)")
        enterErrorState(message: message)
    }
}
