import CoreMotion
import Shared
import UIKit

// MARK: - Tamper Detection Manager

/// Monitors device orientation and movement for tamper detection
@MainActor
public final class TamperDetectionManager: ObservableObject {
    // MARK: - Singleton

    public static let shared = TamperDetectionManager()

    // MARK: - Published Properties

    @Published public private(set) var isTamperDetected = false
    @Published public private(set) var currentOrientation: DeviceOrientation = .unknown
    @Published public private(set) var lastTamperEvent: Date?

    // MARK: - Private Properties

    private var settings: KioskSettings { KioskModeManager.shared.settings }
    private let motionManager = CMMotionManager()
    private var isMonitoring = false
    private var initialOrientation: DeviceOrientation?

    // Movement thresholds
    private let accelerationThreshold: Double = 2.0  // G-force threshold
    private let rotationThreshold: Double = 3.0      // Radians per second

    // MARK: - Initialization

    private init() {
        setupOrientationMonitoring()
    }

    // MARK: - Setup

    private func setupOrientationMonitoring() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )

        updateCurrentOrientation()
    }

    @objc private func orientationChanged() {
        let previousOrientation = currentOrientation
        updateCurrentOrientation()

        // Check for tamper if monitoring is enabled
        guard settings.tamperDetectionEnabled && settings.isEnabled else { return }

        // Check if orientation changed unexpectedly
        if let expected = settings.lockedOrientation ?? initialOrientation {
            if !currentOrientation.matches(expected) && currentOrientation != .unknown {
                triggerTamperAlert(
                    reason: "Orientation changed from \(expected.displayName) to \(currentOrientation.displayName)"
                )
            }
        }
    }

    private func updateCurrentOrientation() {
        let uiOrientation = UIDevice.current.orientation

        // Only update for valid orientations
        if uiOrientation != .unknown && uiOrientation != .faceUp && uiOrientation != .faceDown {
            currentOrientation = DeviceOrientation.from(uiOrientation)
        }
    }

    // MARK: - Monitoring Control

    /// Start tamper detection monitoring
    public func startMonitoring() {
        guard !isMonitoring else { return }
        guard settings.tamperDetectionEnabled else { return }

        isMonitoring = true

        // Record initial orientation if not locked
        if settings.lockedOrientation == nil {
            initialOrientation = currentOrientation
        }

        // Start motion monitoring for sudden movements
        startMotionMonitoring()

        Current.Log.info("Tamper detection started")
    }

    /// Stop tamper detection monitoring
    public func stopMonitoring() {
        isMonitoring = false
        motionManager.stopDeviceMotionUpdates()
        NotificationCenter.default.removeObserver(
            self,
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        UIDevice.current.endGeneratingDeviceOrientationNotifications()

        Current.Log.info("Tamper detection stopped")
    }

    /// Reset tamper state
    public func resetTamperState() {
        isTamperDetected = false
        lastTamperEvent = nil

        // Notify sensor provider
        NotificationCenter.default.post(name: .tamperStateChanged, object: nil)

        Current.Log.info("Tamper state reset")
    }

    /// Lock current orientation as expected orientation
    public func lockCurrentOrientation() {
        KioskModeManager.shared.updateSetting(\.lockedOrientation, to: currentOrientation)
        initialOrientation = currentOrientation

        Current.Log.info("Orientation locked to: \(currentOrientation.displayName)")
    }

    // MARK: - Motion Monitoring

    private func startMotionMonitoring() {
        guard motionManager.isDeviceMotionAvailable else {
            Current.Log.warning("Device motion not available")
            return
        }

        motionManager.deviceMotionUpdateInterval = 0.1

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self, let motion else { return }
            // Already on main queue, call directly
            self.checkForSuddenMovement(motion: motion)
        }
    }

    private func checkForSuddenMovement(motion: CMDeviceMotion) {
        let acceleration = motion.userAcceleration
        let totalAcceleration = sqrt(
            pow(acceleration.x, 2) +
            pow(acceleration.y, 2) +
            pow(acceleration.z, 2)
        )

        let rotation = motion.rotationRate
        let totalRotation = sqrt(
            pow(rotation.x, 2) +
            pow(rotation.y, 2) +
            pow(rotation.z, 2)
        )

        // Check for sudden movement
        if totalAcceleration > accelerationThreshold {
            triggerTamperAlert(reason: "Sudden movement detected (acceleration: \(String(format: "%.1f", totalAcceleration))g)")
        }

        // Check for rapid rotation
        if totalRotation > rotationThreshold {
            triggerTamperAlert(reason: "Rapid rotation detected")
        }
    }

    // MARK: - Tamper Alert

    private func triggerTamperAlert(reason: String) {
        // Debounce - don't trigger too frequently
        if let lastEvent = lastTamperEvent,
           Date().timeIntervalSince(lastEvent) < 5.0 {
            return
        }

        isTamperDetected = true
        lastTamperEvent = Date()

        Current.Log.warning("Tamper detected: \(reason)")

        // Play warning feedback
        TouchFeedbackManager.shared.playFeedback(for: .warning)

        // Notify sensor provider to report to HA
        NotificationCenter.default.post(
            name: .tamperStateChanged,
            object: nil,
            userInfo: ["reason": reason]
        )

        // Show alert if configured
        showTamperAlert(reason: reason)
    }

    private func showTamperAlert(reason: String) {
        let alert = UIAlertController(
            title: "Tamper Detected",
            message: reason,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Dismiss", style: .default) { [weak self] _ in
            self?.resetTamperState()
        })

        // Present alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let tamperStateChanged = Notification.Name("tamperStateChanged")
}

// MARK: - Tamper Detection Settings View

import SwiftUI

public struct TamperDetectionSettingsView: View {
    @ObservedObject private var manager = TamperDetectionManager.shared
    @ObservedObject private var kioskManager = KioskModeManager.shared

    public init() {}

    public var body: some View {
        Form {
            Section {
                Toggle("Enable Tamper Detection", isOn: Binding(
                    get: { kioskManager.settings.tamperDetectionEnabled },
                    set: { newValue in
                        kioskManager.updateSettings { $0.tamperDetectionEnabled = newValue }
                    }
                ))

            } header: {
                Text("Tamper Detection")
            } footer: {
                Text("Detect when the device is moved or rotated from its expected position.")
            }

            if kioskManager.settings.tamperDetectionEnabled {
                Section {
                    // Current status
                    HStack {
                        Label("Status", systemImage: manager.isTamperDetected ? "exclamationmark.triangle.fill" : "checkmark.shield")
                            .foregroundColor(manager.isTamperDetected ? .orange : .green)
                        Spacer()
                        Text(manager.isTamperDetected ? "Tamper Detected" : "Secure")
                            .foregroundColor(manager.isTamperDetected ? .orange : .green)
                    }

                    // Current orientation
                    HStack {
                        Label("Current Orientation", systemImage: "rotate.3d")
                        Spacer()
                        Text(manager.currentOrientation.displayName)
                            .foregroundColor(.secondary)
                    }

                    // Locked orientation
                    if let locked = kioskManager.settings.lockedOrientation {
                        HStack {
                            Label("Expected Orientation", systemImage: "lock")
                            Spacer()
                            Text(locked.displayName)
                                .foregroundColor(.secondary)
                        }
                    }

                } header: {
                    Text("Status")
                }

                Section {
                    // Lock orientation button
                    Button {
                        manager.lockCurrentOrientation()
                    } label: {
                        Label("Lock Current Orientation", systemImage: "lock.rotation")
                    }

                    // Reset tamper state
                    if manager.isTamperDetected {
                        Button {
                            manager.resetTamperState()
                        } label: {
                            Label("Reset Tamper Alert", systemImage: "arrow.counterclockwise")
                        }
                        .foregroundColor(.orange)
                    }

                    // Clear locked orientation
                    if kioskManager.settings.lockedOrientation != nil {
                        Button {
                            kioskManager.updateSetting(\.lockedOrientation, to: nil)
                        } label: {
                            Label("Clear Locked Orientation", systemImage: "lock.open")
                        }
                        .foregroundColor(.red)
                    }

                } header: {
                    Text("Actions")
                }

                Section {
                    // Picker for expected orientation
                    Picker("Expected Orientation", selection: Binding(
                        get: { kioskManager.settings.expectedOrientation },
                        set: { newValue in
                            kioskManager.updateSettings { $0.expectedOrientation = newValue }
                        }
                    )) {
                        ForEach(DeviceOrientation.allCases.filter { $0 != .unknown && $0 != .faceUp && $0 != .faceDown }, id: \.self) { orientation in
                            Text(orientation.displayName).tag(orientation)
                        }
                    }

                } header: {
                    Text("Configuration")
                } footer: {
                    Text("Set the expected orientation. Tamper alerts will trigger if the device orientation doesn't match.")
                }
            }
        }
        .navigationTitle("Tamper Detection")
    }
}
