import AVFoundation
import Combine
import Foundation
import Shared

// MARK: - Ambient Audio Detector

/// Detects ambient audio levels using the device microphone
@MainActor
public final class AmbientAudioDetector: ObservableObject {
    // MARK: - Singleton

    public static let shared = AmbientAudioDetector()

    // MARK: - Published State

    /// Whether detection is currently active
    @Published public private(set) var isActive: Bool = false

    /// Current ambient audio level in decibels (normalized 0-1)
    @Published public private(set) var audioLevel: Float = 0

    /// Current audio level in dB
    @Published public private(set) var audioLevelDB: Float = -160

    /// Whether loud audio is currently detected
    @Published public private(set) var loudAudioDetected: Bool = false

    /// Microphone authorization status
    @Published public private(set) var authorizationStatus: AVAudioSession.RecordPermission = .undetermined

    /// Error message if detection failed
    @Published public private(set) var errorMessage: String?

    // MARK: - Callbacks

    /// Called when loud audio is detected
    public var onLoudAudioDetected: (() -> Void)?

    /// Called when audio level crosses threshold
    public var onThresholdCrossed: ((Bool) -> Void)?

    // MARK: - Private

    private var settings: KioskSettings { KioskModeManager.shared.settings }
    private var audioRecorder: AVAudioRecorder?
    private var meteringTimer: Timer?

    // Detection settings
    private let sampleInterval: TimeInterval = 0.1 // 100ms
    private var loudThresholdDB: Float = -20 // Adjustable
    private var quietThresholdDB: Float = -50
    private var consecutiveLoudSamples: Int = 0
    private let loudSampleThreshold: Int = 3 // Samples needed to confirm loud

    // MARK: - Initialization

    private init() {
        checkAuthorizationStatus()
    }

    deinit {
        audioRecorder?.stop()
        audioRecorder = nil
        meteringTimer?.invalidate()
        meteringTimer = nil
    }

    // MARK: - Public Methods

    /// Start ambient audio detection
    public func start() {
        guard !isActive else { return }
        guard authorizationStatus == .granted else {
            Current.Log.warning("Microphone not authorized for ambient detection")
            return
        }

        Current.Log.info("Starting ambient audio detection")

        setupAudioRecorder()
        startMetering()
        isActive = true
        errorMessage = nil
    }

    /// Stop ambient audio detection
    public func stop() {
        guard isActive else { return }

        Current.Log.info("Stopping ambient audio detection")

        stopMetering()
        audioRecorder?.stop()
        audioRecorder = nil
        isActive = false
        audioLevel = 0
        audioLevelDB = -160
        loudAudioDetected = false
    }

    /// Request microphone authorization
    public func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                Task { @MainActor in
                    self.checkAuthorizationStatus()
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    /// Set detection threshold in dB (e.g., -20 for loud, -50 for quiet)
    public func setThreshold(loud: Float, quiet: Float) {
        loudThresholdDB = loud
        quietThresholdDB = quiet
    }

    // MARK: - Private Methods

    private func checkAuthorizationStatus() {
        authorizationStatus = AVAudioSession.sharedInstance().recordPermission
    }

    private func setupAudioRecorder() {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker])
            try audioSession.setActive(true)

            // Create temporary file for recording (required by AVAudioRecorder but we don't use it)
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent("ambient_meter.caf")

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatAppleIMA4),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue,
            ]

            audioRecorder = try AVAudioRecorder(url: tempFile, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            Current.Log.info("Audio recorder initialized for ambient detection")
        } catch {
            errorMessage = "Failed to setup audio recorder: \(error.localizedDescription)"
            Current.Log.error("Audio recorder setup error: \(error)")
        }
    }

    private func startMetering() {
        meteringTimer = Timer.scheduledTimer(withTimeInterval: sampleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetering()
            }
        }
    }

    private func stopMetering() {
        meteringTimer?.invalidate()
        meteringTimer = nil
    }

    private func updateMetering() {
        guard let recorder = audioRecorder else { return }

        recorder.updateMeters()

        // Get average power in dB (-160 to 0)
        let averagePower = recorder.averagePower(forChannel: 0)
        audioLevelDB = averagePower

        // Normalize to 0-1 range
        // -160 dB = 0, 0 dB = 1
        audioLevel = max(0, min(1, (averagePower + 160) / 160))

        // Check for loud audio
        if averagePower > loudThresholdDB {
            consecutiveLoudSamples += 1

            if consecutiveLoudSamples >= loudSampleThreshold && !loudAudioDetected {
                loudAudioDetected = true
                onLoudAudioDetected?()
                onThresholdCrossed?(true)
                Current.Log.info("Loud audio detected: \(averagePower) dB")
            }
        } else if averagePower < quietThresholdDB {
            if loudAudioDetected {
                loudAudioDetected = false
                onThresholdCrossed?(false)
                Current.Log.info("Audio returned to quiet: \(averagePower) dB")
            }
            consecutiveLoudSamples = 0
        }
    }
}

// MARK: - Sensor State Access

extension AmbientAudioDetector {
    /// Get audio level for HA sensor reporting (0-100)
    public var audioLevelPercent: Int {
        Int(audioLevel * 100)
    }

    /// Get sensor attributes for HA
    public var sensorAttributes: [String: Any] {
        [
            "level_db": audioLevelDB,
            "level_percent": audioLevelPercent,
            "loud_detected": loudAudioDetected,
            "detection_active": isActive,
            "threshold_loud_db": loudThresholdDB,
            "threshold_quiet_db": quietThresholdDB,
        ]
    }
}

// MARK: - Use Cases

extension AmbientAudioDetector {
    /// Configure for voice activity detection
    public func configureForVoiceDetection() {
        setThreshold(loud: -30, quiet: -45)
    }

    /// Configure for loud noise detection (e.g., smoke alarm)
    public func configureForLoudNoiseDetection() {
        setThreshold(loud: -15, quiet: -30)
    }

    /// Configure for quiet room detection
    public func configureForQuietRoomDetection() {
        setThreshold(loud: -40, quiet: -55)
    }
}
