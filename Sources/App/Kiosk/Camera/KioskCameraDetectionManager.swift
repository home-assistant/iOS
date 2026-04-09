import AVFoundation
import Combine
import Foundation
import Shared
import UIKit

// MARK: - Kiosk Camera Detection Manager

/// Coordinates camera-based motion and presence detection for kiosk mode
@MainActor
public final class KioskCameraDetectionManager: ObservableObject {
    // MARK: - Singleton

    public static let shared = KioskCameraDetectionManager()

    // MARK: - Published State

    /// Whether any camera detection is currently active
    @Published public private(set) var isActive: Bool = false

    /// Current motion detected state
    @Published public private(set) var motionDetected: Bool = false

    /// Current presence detected state
    @Published public private(set) var presenceDetected: Bool = false

    /// Current face detected state
    @Published public private(set) var faceDetected: Bool = false

    /// Number of faces detected
    @Published public private(set) var faceCount: Int = 0

    /// Camera authorization status
    @Published public private(set) var authorizationStatus: AVAuthorizationStatus = .notDetermined

    // MARK: - Callbacks

    /// Called when motion is detected (for wake trigger)
    public var onMotionDetected: (() -> Void)?

    /// Called when presence state changes
    public var onPresenceChanged: ((Bool) -> Void)?

    // MARK: - Private

    private var settings: KioskSettings { KioskModeManager.shared.settings }
    private let motionDetector = KioskCameraMotionDetector()
    private let presenceDetector = KioskPresenceDetector()
    private var cancellables = Set<AnyCancellable>()

    /// Timer for periodic activity updates while presence is detected
    private var presenceActivityTimer: Timer?

    /// Interval for presence activity updates (keeps idle timer reset while someone is present)
    private let presenceActivityInterval: TimeInterval = 5.0

    // MARK: - Initialization

    private init() {
        setupBindings()
        checkAuthorizationStatus()
    }

    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    // MARK: - Public Methods

    /// Start camera detection based on current settings
    public func start() {
        guard !isActive else { return }

        Current.Log.info("Starting camera detection manager")

        if settings.cameraMotionEnabled {
            motionDetector.start()
        }

        if settings.cameraPresenceEnabled || settings.cameraFaceDetectionEnabled {
            presenceDetector.start(faceDetectionEnabled: settings.cameraFaceDetectionEnabled)
        }

        isActive = settings.cameraMotionEnabled || settings.cameraPresenceEnabled
            || settings.cameraFaceDetectionEnabled
    }

    /// Stop all camera detection
    public func stop() {
        guard isActive else { return }

        Current.Log.info("Stopping camera detection manager")

        stopPresenceActivityTimer()
        motionDetector.stop()
        presenceDetector.stop()
        isActive = false
    }

    /// Restart detection (e.g., after settings change)
    public func restart() {
        stop()
        start()
    }

    /// Request camera authorization
    public func requestAuthorization() async -> Bool {
        let granted = await motionDetector.requestAuthorization()
        checkAuthorizationStatus()
        return granted
    }

    // MARK: - Private Methods

    private func checkAuthorizationStatus() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    private func setupBindings() {
        // Bind motion detector state
        motionDetector.$motionDetected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detected in
                self?.motionDetected = detected
                if detected {
                    self?.handleMotionDetected()
                }
            }
            .store(in: &cancellables)

        // Bind presence detector state
        presenceDetector.$personDetected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detected in
                let previousState = self?.presenceDetected ?? false
                self?.presenceDetected = detected
                if detected != previousState {
                    self?.handlePresenceChanged(detected)
                }
            }
            .store(in: &cancellables)

        // Bind face detection state
        presenceDetector.$faceDetected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detected in
                self?.faceDetected = detected
            }
            .store(in: &cancellables)

        presenceDetector.$faceCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.faceCount = count
            }
            .store(in: &cancellables)

        // Bind authorization status from both detectors
        Publishers.Merge(
            motionDetector.$authorizationStatus,
            presenceDetector.$authorizationStatus
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] status in
            self?.authorizationStatus = status
        }
        .store(in: &cancellables)
    }

    private func handleMotionDetected() {
        Current.Log.info("Camera motion detected")
        onMotionDetected?()
    }

    private func handlePresenceChanged(_ detected: Bool) {
        Current.Log.info("Presence changed: \(detected ? "detected" : "absent")")
        onPresenceChanged?(detected)

        if detected {
            startPresenceActivityTimer()
        } else {
            stopPresenceActivityTimer()
        }
    }

    // MARK: - Presence Activity Timer

    /// Starts a timer that periodically records activity while presence is detected.
    /// This prevents the screensaver from triggering while someone is standing in front of the device.
    private func startPresenceActivityTimer() {
        stopPresenceActivityTimer()

        guard settings.wakeOnCameraPresence else { return }

        presenceActivityTimer = Timer.scheduledTimer(
            withTimeInterval: presenceActivityInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, presenceDetected else {
                    self?.stopPresenceActivityTimer()
                    return
                }

                Current.Log.verbose("Presence activity tick - keeping screen awake")
                KioskModeManager.shared.recordActivity(source: "camera_presence")
            }
        }
    }

    private func stopPresenceActivityTimer() {
        presenceActivityTimer?.invalidate()
        presenceActivityTimer = nil
    }
}
