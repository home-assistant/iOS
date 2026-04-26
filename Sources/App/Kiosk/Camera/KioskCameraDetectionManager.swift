import AVFoundation
import Combine
import Foundation
import Shared
import UIKit

// MARK: - Kiosk Camera Detection Manager

/// Coordinates camera-based motion detection for kiosk mode
@MainActor
public final class KioskCameraDetectionManager: ObservableObject {
    // MARK: - Singleton

    public static let shared = KioskCameraDetectionManager()

    // MARK: - Published State

    /// Whether any camera detection is currently active
    @Published public private(set) var isActive: Bool = false

    /// Current motion detected state
    @Published public private(set) var motionDetected: Bool = false

    /// Camera authorization status
    @Published public private(set) var authorizationStatus: AVAuthorizationStatus = .notDetermined

    // MARK: - Callbacks

    /// Called when motion is detected (for wake trigger)
    public var onMotionDetected: (() -> Void)?

    // MARK: - Private

    private var settings: KioskSettings { KioskModeManager.shared.settings }
    private let motionDetector = KioskCameraMotionDetector()
    private var cancellables = Set<AnyCancellable>()

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

    /// Start camera detection based on current settings.
    /// `isActive` reflects the underlying detector state (bound in setupBindings),
    /// so it stays false if the detector bails out (e.g. camera permission denied).
    public func start() {
        Current.Log.info("Starting camera detection manager")

        if settings.cameraMotionEnabled {
            motionDetector.start()
        }
    }

    /// Stop all camera detection
    public func stop() {
        Current.Log.info("Stopping camera detection manager")
        motionDetector.stop()
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
        motionDetector.$isActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in
                self?.isActive = active
            }
            .store(in: &cancellables)

        motionDetector.$motionDetected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detected in
                self?.motionDetected = detected
                if detected {
                    self?.handleMotionDetected()
                }
            }
            .store(in: &cancellables)

        motionDetector.$authorizationStatus
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
}
