import Shared
import UIKit

// MARK: - Guided Access Manager

/// Manages iOS Guided Access integration for enhanced kiosk security
@MainActor
public final class GuidedAccessManager: ObservableObject {
    // MARK: - Singleton

    public static let shared = GuidedAccessManager()

    // MARK: - Published Properties

    @Published public private(set) var isGuidedAccessEnabled = false
    @Published public private(set) var isGuidedAccessActive = false

    // MARK: - Private Properties

    private var settings: KioskSettings { KioskModeManager.shared.settings }

    // MARK: - Initialization

    private init() {
        setupNotifications()
        checkGuidedAccessStatus()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(guidedAccessStatusChanged),
            name: UIAccessibility.guidedAccessStatusDidChangeNotification,
            object: nil
        )
    }

    @objc private func guidedAccessStatusChanged() {
        checkGuidedAccessStatus()
    }

    // MARK: - Status Check

    /// Check current Guided Access status
    public func checkGuidedAccessStatus() {
        isGuidedAccessEnabled = UIAccessibility.isGuidedAccessEnabled

        // Update sensor provider
        NotificationCenter.default.post(name: .guidedAccessStatusChanged, object: nil)

        Current.Log.info("Guided Access status: \(isGuidedAccessEnabled ? "enabled" : "disabled")")
    }

    // MARK: - Guided Access Control

    /// Request to enable Guided Access
    /// Note: iOS does not provide a programmatic API to enable Guided Access
    /// This provides guidance to users on how to enable it manually
    public func requestEnableGuidedAccess() {
        Current.Log.info("Guided Access must be enabled manually via Settings > Accessibility > Guided Access")

        // Show alert with instructions
        let alert = UIAlertController(
            title: "Enable Guided Access",
            message: """
            To enable Guided Access for enhanced kiosk security:

            1. Go to Settings > Accessibility > Guided Access
            2. Turn on Guided Access
            3. Set a Guided Access passcode
            4. Triple-click the side/home button to start a Guided Access session

            This will prevent users from exiting HAFrame.
            """,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })

        alert.addAction(UIAlertAction(title: "OK", style: .cancel))

        // Present alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }

    /// Show instructions for starting Guided Access session
    public func showStartSessionInstructions() {
        let alert = UIAlertController(
            title: "Start Guided Access Session",
            message: """
            To lock HAFrame in kiosk mode:

            Triple-click the side button (or home button on older devices) to start Guided Access.

            Make sure Guided Access is enabled in Settings > Accessibility first.
            """,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default))

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }

    /// Check if Guided Access should be recommended
    public var shouldRecommendGuidedAccess: Bool {
        // Recommend if kiosk mode is enabled but Guided Access is not
        return settings.isEnabled &&
               settings.guidedAccessEnabled &&
               !isGuidedAccessEnabled
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let guidedAccessStatusChanged = Notification.Name("guidedAccessStatusChanged")
}

// MARK: - Guided Access Settings View

import SwiftUI

public struct GuidedAccessSettingsView: View {
    @ObservedObject private var manager = GuidedAccessManager.shared
    @ObservedObject private var kioskManager = KioskModeManager.shared

    public init() {}

    public var body: some View {
        Form {
            Section {
                // Status
                HStack {
                    Label("Guided Access", systemImage: "lock.shield")
                    Spacer()
                    Text(manager.isGuidedAccessEnabled ? "Active" : "Inactive")
                        .foregroundColor(manager.isGuidedAccessEnabled ? .green : .secondary)
                }

                // Enable in settings toggle
                Toggle("Use Guided Access", isOn: Binding(
                    get: { kioskManager.settings.guidedAccessEnabled },
                    set: { newValue in
                        kioskManager.updateSettings { $0.guidedAccessEnabled = newValue }
                    }
                ))

            } header: {
                Text("Guided Access")
            } footer: {
                Text("Guided Access prevents users from leaving the app and disables hardware buttons.")
            }

            if kioskManager.settings.guidedAccessEnabled {
                Section {
                    if !manager.isGuidedAccessEnabled {
                        // Setup instructions
                        Button {
                            manager.requestEnableGuidedAccess()
                        } label: {
                            Label("Setup Guided Access", systemImage: "gear")
                        }

                        Text("Guided Access needs to be configured in iOS Settings before use.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        // Start session button
                        Button {
                            manager.showStartSessionInstructions()
                        } label: {
                            Label("Start Session Instructions", systemImage: "play.circle")
                        }

                        Text("Triple-click the side button to start or end a Guided Access session.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Actions")
                }

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        instructionRow(number: 1, text: "Go to Settings > Accessibility > Guided Access")
                        instructionRow(number: 2, text: "Turn on Guided Access")
                        instructionRow(number: 3, text: "Tap Passcode Settings and set a Guided Access passcode")
                        instructionRow(number: 4, text: "Return to HAFrame")
                        instructionRow(number: 5, text: "Triple-click the side button")
                        instructionRow(number: 6, text: "Tap Start in the top right")
                    }
                    .padding(.vertical, 5)
                } header: {
                    Text("Setup Instructions")
                }
            }
        }
        .navigationTitle("Guided Access")
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
        }
    }
}
