import Shared
import UIKit

// MARK: - Crash Recovery Manager

/// Manages crash detection and recovery for kiosk mode
@MainActor
public final class CrashRecoveryManager {
    // MARK: - Singleton

    public static let shared = CrashRecoveryManager()

    // MARK: - Private Properties

    private let crashFlagKey = "KioskMode.didCrash"
    private let crashCountKey = "KioskMode.crashCount"
    private let lastCrashKey = "KioskMode.lastCrashDate"
    private let launchTimeKey = "KioskMode.lastLaunchTime"

    private var settings: KioskSettings { KioskModeManager.shared.settings }

    // MARK: - Initialization

    private init() {}

    // MARK: - Crash Detection

    /// Call this at app launch to detect if previous session crashed
    public func checkForPreviousCrash() -> Bool {
        let didCrash = UserDefaults.standard.bool(forKey: crashFlagKey)

        if didCrash {
            // Increment crash count
            let crashCount = UserDefaults.standard.integer(forKey: crashCountKey) + 1
            UserDefaults.standard.set(crashCount, forKey: crashCountKey)
            UserDefaults.standard.set(Date(), forKey: lastCrashKey)

            Current.Log.warning("Previous session crashed. Total crash count: \(crashCount)")

            // Clear crash flag
            UserDefaults.standard.set(false, forKey: crashFlagKey)

            return true
        }

        return false
    }

    /// Call this when app launches normally (after any crash handling)
    public func markAppLaunched() {
        // Set crash flag - will be cleared on clean termination
        UserDefaults.standard.set(true, forKey: crashFlagKey)
        UserDefaults.standard.set(Date(), forKey: launchTimeKey)

        Current.Log.info("App launch recorded")
    }

    /// Call this when app terminates cleanly
    public func markCleanTermination() {
        UserDefaults.standard.set(false, forKey: crashFlagKey)

        Current.Log.info("Clean termination recorded")
    }

    /// Get crash statistics
    public var crashCount: Int {
        UserDefaults.standard.integer(forKey: crashCountKey)
    }

    public var lastCrashDate: Date? {
        UserDefaults.standard.object(forKey: lastCrashKey) as? Date
    }

    public var lastLaunchDate: Date? {
        UserDefaults.standard.object(forKey: launchTimeKey) as? Date
    }

    /// Reset crash statistics
    public func resetCrashStatistics() {
        UserDefaults.standard.set(0, forKey: crashCountKey)
        UserDefaults.standard.removeObject(forKey: lastCrashKey)

        Current.Log.info("Crash statistics reset")
    }

    // MARK: - Recovery Actions

    /// Handle recovery after a crash
    public func handleCrashRecovery() {
        guard settings.autoRestartOnCrash else {
            Current.Log.info("Auto-restart on crash disabled, skipping recovery")
            return
        }

        Current.Log.info("Executing crash recovery...")

        // Report crash to HA
        NotificationCenter.default.post(name: .appCrashRecovered, object: nil)

        // Check if we're in a crash loop (multiple crashes in short time)
        if isCrashLoop {
            handleCrashLoop()
            return
        }

        // Restore kiosk mode if it was enabled
        if settings.isEnabled {
            Current.Log.info("Restoring kiosk mode after crash")
            KioskModeManager.shared.enableKioskMode()
        }
    }

    /// Check if we're in a crash loop
    private var isCrashLoop: Bool {
        // Consider it a crash loop if 3+ crashes in 5 minutes
        let recentCrashThreshold = 3
        let timeWindow: TimeInterval = 300 // 5 minutes

        guard crashCount >= recentCrashThreshold else { return false }

        if let lastCrash = lastCrashDate {
            return Date().timeIntervalSince(lastCrash) < timeWindow
        }

        return false
    }

    /// Handle crash loop scenario
    private func handleCrashLoop() {
        Current.Log.error("Crash loop detected! Disabling kiosk mode for safety.")

        // Disable kiosk mode to allow user to troubleshoot
        KioskModeManager.shared.updateSetting(\.isEnabled, to: false)

        // Show alert
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.showCrashLoopAlert()
        }
    }

    private func showCrashLoopAlert() {
        let alert = UIAlertController(
            title: "Crash Loop Detected",
            message: "The app has crashed multiple times. Kiosk mode has been temporarily disabled to allow troubleshooting.\n\nCrash count: \(crashCount)",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Reset Crash Count", style: .destructive) { [weak self] _ in
            self?.resetCrashStatistics()
        })

        alert.addAction(UIAlertAction(title: "OK", style: .default))

        // Present alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }

    // MARK: - Background State Handling

    /// Call when app enters background
    public func handleEnterBackground() {
        // Save current state for recovery
        KioskModeManager.shared.saveSettings()

        Current.Log.info("App entering background, state saved")
    }

    /// Call when app becomes active
    public func handleBecomeActive() {
        // Restore state if needed
        if settings.isEnabled && !KioskModeManager.shared.isKioskModeActive {
            Current.Log.info("Restoring kiosk mode after becoming active")
            KioskModeManager.shared.enableKioskMode()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let appCrashRecovered = Notification.Name("appCrashRecovered")
}

// MARK: - Crash Recovery Settings View

import SwiftUI

public struct CrashRecoverySettingsView: View {
    @ObservedObject private var kioskManager = KioskModeManager.shared
    private let crashManager = CrashRecoveryManager.shared

    public init() {}

    public var body: some View {
        Form {
            Section {
                Toggle("Auto-Restart on Crash", isOn: Binding(
                    get: { kioskManager.settings.autoRestartOnCrash },
                    set: { newValue in
                        kioskManager.updateSettings { $0.autoRestartOnCrash = newValue }
                    }
                ))
            } header: {
                Text("Crash Recovery")
            } footer: {
                Text("Automatically restore kiosk mode if the app crashes. If multiple crashes occur in quick succession, kiosk mode will be temporarily disabled.")
            }

            Section {
                // Crash count
                HStack {
                    Label("Total Crashes", systemImage: "exclamationmark.triangle")
                    Spacer()
                    Text("\(crashManager.crashCount)")
                        .foregroundColor(.secondary)
                }

                // Last crash
                if let lastCrash = crashManager.lastCrashDate {
                    HStack {
                        Label("Last Crash", systemImage: "clock")
                        Spacer()
                        Text(lastCrash, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }

                // Last launch
                if let lastLaunch = crashManager.lastLaunchDate {
                    HStack {
                        Label("Current Session", systemImage: "play.circle")
                        Spacer()
                        Text(lastLaunch, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }

            } header: {
                Text("Statistics")
            }

            if crashManager.crashCount > 0 {
                Section {
                    Button(role: .destructive) {
                        crashManager.resetCrashStatistics()
                    } label: {
                        Label("Reset Crash Statistics", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Crash Recovery")
    }
}
