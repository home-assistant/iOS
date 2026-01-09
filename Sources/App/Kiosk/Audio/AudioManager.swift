import AVFoundation
import Combine
import MediaPlayer
import Shared
import UIKit

// MARK: - Audio Manager

/// Manages audio playback, TTS, and volume control for kiosk mode
@MainActor
public final class AudioManager: NSObject, ObservableObject {
    // MARK: - Singleton

    public static let shared = AudioManager()

    // MARK: - Published State

    /// Current system volume (0.0 - 1.0)
    @Published public private(set) var currentVolume: Float = 0.5

    /// Whether TTS is currently speaking
    @Published public private(set) var isSpeaking: Bool = false

    /// Whether audio is currently playing
    @Published public private(set) var isPlaying: Bool = false

    /// Current audio playback progress (0.0 - 1.0)
    @Published public private(set) var playbackProgress: Float = 0

    // MARK: - Private

    private var settings: KioskSettings { KioskModeManager.shared.settings }
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var urlPlayer: AVPlayer?
    private var progressTimer: Timer?
    private var volumeView: MPVolumeView?

    // Alert sounds
    private var alertSounds: [AlertType: SystemSoundID] = [:]

    // MARK: - Initialization

    private override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
        setupVolumeObserver()
        registerAlertSounds()
    }

    deinit {
        // Stop any playing audio
        audioPlayer?.stop()
        urlPlayer?.pause()
        progressTimer?.invalidate()

        // Dispose alert sounds
        for soundID in alertSounds.values {
            AudioServicesDisposeSystemSoundID(soundID)
        }

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)

        // Remove observers
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods - TTS

    /// Speak text using text-to-speech
    public func speak(_ text: String, priority: TTSPriority = .normal) {
        guard settings.ttsEnabled else { return }

        // If high priority, stop current speech
        if priority == .high && synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // If already speaking and not high priority, queue it
        if synthesizer.isSpeaking && priority != .high {
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = settings.ttsVolume

        // Use system default voice
        let languageCode = Locale.current.languageCode ?? "en-US"
        if let voice = AVSpeechSynthesisVoice(language: languageCode) {
            utterance.voice = voice
        }

        synthesizer.speak(utterance)
        isSpeaking = true

        Current.Log.info("TTS: \(text)")
    }

    /// Stop current TTS speech
    public func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    // MARK: - Public Methods - Audio Playback

    /// Play audio from a URL (local or remote)
    public func playAudio(from url: URL, volume: Float? = nil) {
        stopAudio()

        let playVolume = volume ?? settings.ttsVolume

        if url.isFileURL {
            playLocalAudio(url: url, volume: playVolume)
        } else {
            playRemoteAudio(url: url, volume: playVolume)
        }
    }

    /// Play audio from a URL string
    public func playAudio(from urlString: String, volume: Float? = nil) {
        guard let url = URL(string: urlString) else {
            Current.Log.warning("Invalid audio URL: \(urlString)")
            return
        }
        playAudio(from: url, volume: volume)
    }

    /// Stop current audio playback
    public func stopAudio() {
        // Remove observer to prevent memory leak and duplicate callbacks
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)

        audioPlayer?.stop()
        audioPlayer = nil

        urlPlayer?.pause()
        urlPlayer = nil

        progressTimer?.invalidate()
        progressTimer = nil

        isPlaying = false
        playbackProgress = 0
    }

    /// Pause audio playback
    public func pauseAudio() {
        audioPlayer?.pause()
        urlPlayer?.pause()
        isPlaying = false
    }

    /// Resume audio playback
    public func resumeAudio() {
        audioPlayer?.play()
        urlPlayer?.play()
        isPlaying = true
    }

    // MARK: - Public Methods - Alerts

    /// Play an alert sound
    public func playAlert(_ type: AlertType) {
        guard settings.audioAlertsEnabled else { return }

        if let soundID = alertSounds[type] {
            AudioServicesPlaySystemSound(soundID)
        } else {
            // Fallback to system sounds
            switch type {
            case .critical:
                AudioServicesPlaySystemSound(1005) // System alert
            case .warning:
                AudioServicesPlaySystemSound(1007) // SMS received
            case .info:
                AudioServicesPlaySystemSound(1003) // Tweet
            case .success:
                AudioServicesPlaySystemSound(1001) // Received mail
            case .doorbell:
                AudioServicesPlaySystemSound(1016) // Ding dong (if available)
            }
        }

        Current.Log.info("Alert played: \(type)")
    }

    /// Play haptic feedback
    public func playHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard settings.touchHapticEnabled else { return }

        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    // MARK: - Public Methods - Volume Control

    /// Set system volume
    public func setVolume(_ volume: Float) {
        let clampedVolume = max(0, min(1, volume))

        // Use MPVolumeView to set system volume
        if volumeView == nil {
            volumeView = MPVolumeView(frame: .zero)
        }

        if let slider = volumeView?.subviews.first(where: { $0 is UISlider }) as? UISlider {
            slider.value = clampedVolume
        }

        currentVolume = clampedVolume
        Current.Log.info("Volume set to: \(Int(clampedVolume * 100))%")
    }

    /// Get current volume level
    public func getVolume() -> Float {
        currentVolume
    }

    /// Mute audio
    public func mute() {
        setVolume(0)
    }

    /// Unmute to previous volume or default
    public func unmute(to volume: Float = 0.5) {
        setVolume(volume)
    }

    // MARK: - Private Methods

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
        } catch {
            Current.Log.error("Failed to setup audio session: \(error)")
        }
    }

    private func setupVolumeObserver() {
        // Observe system volume changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(volumeDidChange),
            name: NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification"),
            object: nil
        )

        // Get initial volume
        currentVolume = AVAudioSession.sharedInstance().outputVolume
    }

    @objc private func volumeDidChange(_ notification: Notification) {
        if let volume = notification.userInfo?["AVSystemController_AudioVolumeNotificationParameter"] as? Float {
            currentVolume = volume
        }
    }

    private func registerAlertSounds() {
        // Register custom alert sounds from bundle if available
        let alertTypes: [AlertType] = [.critical, .warning, .info, .success, .doorbell]

        for type in alertTypes {
            if let soundURL = Bundle.main.url(forResource: type.soundFileName, withExtension: "wav") {
                var soundID: SystemSoundID = 0
                AudioServicesCreateSystemSoundID(soundURL as CFURL, &soundID)
                alertSounds[type] = soundID
            }
        }
    }

    private func playLocalAudio(url: URL, volume: Float) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = volume
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true
            startProgressTimer()
            Current.Log.info("Playing local audio: \(url.lastPathComponent)")
        } catch {
            Current.Log.error("Failed to play local audio: \(error)")
        }
    }

    private func playRemoteAudio(url: URL, volume: Float) {
        let playerItem = AVPlayerItem(url: url)
        urlPlayer = AVPlayer(playerItem: playerItem)
        urlPlayer?.volume = volume
        urlPlayer?.play()
        isPlaying = true

        // Observe playback end
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )

        startProgressTimer()
        Current.Log.info("Playing remote audio: \(url.absoluteString)")
    }

    @objc private func playerDidFinish(_ notification: Notification) {
        stopAudio()
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }

    private func updateProgress() {
        if let player = audioPlayer {
            if player.duration > 0 {
                playbackProgress = Float(player.currentTime / player.duration)
            }
        } else if let player = urlPlayer,
                  let currentItem = player.currentItem {
            let duration = currentItem.duration.seconds
            let current = player.currentTime().seconds
            if duration.isFinite && duration > 0 {
                playbackProgress = Float(current / duration)
            }
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AudioManager: AVSpeechSynthesizerDelegate {
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioManager: AVAudioPlayerDelegate {
    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stopAudio()
        }
    }
}

// MARK: - Supporting Types

public enum TTSPriority {
    case normal
    case high
}

public enum AlertType: String, CaseIterable {
    case critical
    case warning
    case info
    case success
    case doorbell

    var soundFileName: String {
        "alert_\(rawValue)"
    }
}

// MARK: - HA Audio Integration

extension AudioManager {
    /// Play media from Home Assistant media_player service
    public func playHAMedia(contentId: String, contentType: String = "music") {
        // Construct media URL from HA
        guard let server = Current.servers.all.first,
              let baseURL = server.info.connection.activeURL() else {
            Current.Log.warning("No HA server available for media playback")
            return
        }

        // For media_source content IDs
        if contentId.hasPrefix("media-source://") {
            let mediaPath = "/api/media_source/local/\(contentId.replacingOccurrences(of: "media-source://", with: ""))"
            if let url = URL(string: baseURL.absoluteString + mediaPath) {
                playAudio(from: url)
            }
        } else if let url = URL(string: contentId) {
            // Direct URL
            playAudio(from: url)
        }
    }

    /// Handle HA notification command for audio
    public func handleCommand(_ command: AudioCommand) {
        switch command {
        case let .tts(message, volume):
            if let vol = volume {
                let previousVolume = currentVolume
                setVolume(vol)
                speak(message, priority: .high)
                // Restore volume after speech (approximation)
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(message.count) * 0.08) { [weak self] in
                    self?.setVolume(previousVolume)
                }
            } else {
                speak(message)
            }

        case let .playMedia(url, volume):
            playAudio(from: url, volume: volume)

        case .stop:
            stopAudio()
            stopSpeaking()

        case let .setVolume(level):
            setVolume(level)

        case let .alert(type):
            playAlert(type)
        }
    }
}

public enum AudioCommand {
    case tts(message: String, volume: Float?)
    case playMedia(url: String, volume: Float?)
    case stop
    case setVolume(level: Float)
    case alert(type: AlertType)
}
