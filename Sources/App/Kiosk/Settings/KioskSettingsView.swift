import Shared
import SwiftUI

// MARK: - Main Kiosk Settings View

struct KioskSettingsView: View {
    @ObservedObject private var manager = KioskModeManager.shared
    @State private var settings: KioskSettings
    @State private var showingPINSetup = false
    @State private var showingPINEntry = false
    @State private var showingDashboardConfig = false
    @State private var showingScreensaverConfig = false
    @State private var showingEntityTriggers = false
    @State private var showingAppLauncher = false
    @State private var showingAuthError = false
    @State private var authErrorMessage = ""

    init() {
        _settings = State(initialValue: KioskModeManager.shared.settings)
    }

    var body: some View {
        Form {
            // Quick Enable Section
            kioskModeSection

            if !manager.isKioskModeActive {
                // Only show config when kiosk mode is disabled
                coreSettingsSection
                dashboardSection
                autoRefreshSection
                brightnessSection
                screensaverSection
                triggersSection
                presenceSection
                cameraPopupSection
                audioSection
                deviceSection
            }
        }
        .navigationTitle("Kiosk Mode")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: settings) { newValue in
            manager.updateSettings(newValue)
        }
        .sheet(isPresented: $showingPINSetup) {
            PINSetupView(currentPIN: $settings.exitPIN)
        }
        .sheet(isPresented: $showingPINEntry) {
            PINEntryView(isPresented: $showingPINEntry) {
                manager.disableKioskMode()
            }
        }
        .sheet(isPresented: $showingDashboardConfig) {
            DashboardConfigurationView(dashboards: $settings.dashboards, primaryURL: $settings.primaryDashboardURL)
        }
        .sheet(isPresented: $showingScreensaverConfig) {
            ScreensaverConfigView(settings: $settings)
        }
        .sheet(isPresented: $showingEntityTriggers) {
            EntityTriggersView(
                wakeEntities: $settings.wakeEntities,
                sleepEntities: $settings.sleepEntities,
                actionTriggers: $settings.entityTriggers
            )
        }
        .alert("Authentication Error", isPresented: $showingAuthError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authErrorMessage)
        }
    }

    // MARK: - Kiosk Mode Section

    private var kioskModeSection: some View {
        Section {
            if manager.isKioskModeActive {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.green)
                        Text("Kiosk Mode Active")
                            .font(.headline)
                    }

                    Text("Screen: \(manager.screenState.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let screensaver = manager.activeScreensaverMode {
                        Text("Screensaver: \(screensaver.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button(role: .destructive) {
                        attemptKioskExit()
                    } label: {
                        Label("Exit Kiosk Mode", systemImage: "lock.open")
                    }
                    .accessibilityHint("Double-tap to exit kiosk mode. Authentication may be required.")
                }
            } else {
                Toggle(isOn: Binding(
                    get: { manager.isKioskModeActive },
                    set: { newValue in
                        if newValue {
                            manager.enableKioskMode()
                        }
                    }
                )) {
                    Label("Enable Kiosk Mode", systemImage: "lock")
                }
            }
        } header: {
            Text("Kiosk Mode")
        } footer: {
            if !manager.isKioskModeActive {
                Text("When enabled, the display will be locked to the dashboard with optional PIN protection.")
            }
        }
    }

    // MARK: - Core Settings Section

    private var coreSettingsSection: some View {
        Section {
            // PIN Setup
            Button {
                showingPINSetup = true
            } label: {
                HStack {
                    Label("Exit PIN", systemImage: "key")
                    Spacer()
                    Text(settings.exitPIN.isEmpty ? "Not Set" : "••••")
                        .foregroundColor(.secondary)
                }
            }

            Toggle(isOn: $settings.allowBiometricExit) {
                Label("Allow Face ID / Touch ID", systemImage: "faceid")
            }

            Toggle(isOn: $settings.allowDevicePasscodeExit) {
                Label("Use Device Passcode", systemImage: "lock.shield")
            }

            Toggle(isOn: $settings.navigationLockdown) {
                Label("Lock Navigation", systemImage: "hand.raised")
            }

            Toggle(isOn: $settings.hideStatusBar) {
                Label("Hide Status Bar", systemImage: "rectangle.expand.vertical")
            }

            Toggle(isOn: $settings.edgeProtection) {
                Label("Edge Touch Protection", systemImage: "rectangle.dashed")
            }

            // Secret Exit Gesture
            Toggle(isOn: $settings.secretExitGestureEnabled) {
                Label("Secret Exit Gesture", systemImage: "hand.tap")
            }

            if settings.secretExitGestureEnabled {
                Picker("Exit Gesture Corner", selection: $settings.secretExitGestureCorner) {
                    ForEach(ScreenCorner.allCases, id: \.self) { corner in
                        Text(corner.displayName).tag(corner)
                    }
                }

                Stepper(value: $settings.secretExitGestureTaps, in: 2...5) {
                    Label("Taps Required: \(settings.secretExitGestureTaps)", systemImage: "number")
                }
            }
        } header: {
            Text("Security & Display")
        } footer: {
            if settings.secretExitGestureEnabled {
                Text("Tap the \(settings.secretExitGestureCorner.displayName.lowercased()) corner \(settings.secretExitGestureTaps) times to access kiosk settings when locked. This is your escape hatch if navigation is locked down.")
            } else {
                Text("Navigation lockdown prevents back gestures and pull-to-refresh. Edge protection ignores touches near screen edges. Warning: Without the secret exit gesture, you can only exit kiosk mode via Home Assistant commands.")
            }
        }
    }

    // MARK: - Dashboard Section

    private var dashboardSection: some View {
        Section {
            NavigationLink {
                DashboardPickerView(selectedPath: $settings.primaryDashboardURL)
            } label: {
                HStack {
                    Label("Default Dashboard", systemImage: "house")
                    Spacer()
                    Text(settings.primaryDashboardURL.isEmpty ? "Not Set" : settings.primaryDashboardURL)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Toggle(isOn: $settings.appendKioskParameter) {
                Label("Kiosk Mode URL", systemImage: "rectangle.on.rectangle.slash")
            }

            Button {
                showingDashboardConfig = true
            } label: {
                HStack {
                    Label("Configure Dashboards", systemImage: "rectangle.stack")
                    Spacer()
                    Text("\(settings.dashboards.count)")
                        .foregroundColor(.secondary)
                }
            }

            Toggle(isOn: $settings.rotationEnabled) {
                Label("Rotate Dashboards", systemImage: "arrow.2.squarepath")
            }

            if settings.rotationEnabled {
                Stepper(value: $settings.rotationInterval, in: 10...3600, step: 10) {
                    Label("Rotation: \(Int(settings.rotationInterval))s", systemImage: "timer")
                }

                Toggle(isOn: $settings.pauseRotationOnTouch) {
                    Label("Pause on Touch", systemImage: "hand.tap")
                }
            }
        } header: {
            Text("Dashboard")
        } footer: {
            Text(settings.appendKioskParameter
                 ? "Kiosk Mode URL appends ?kiosk to hide the HA sidebar/header (requires kiosk-mode HACS integration)."
                 : "Select a dashboard from Home Assistant or enter a custom path.")
        }
    }

    // MARK: - Auto Refresh Section

    private var autoRefreshSection: some View {
        Section {
            Picker("Periodic Refresh", selection: $settings.autoRefreshInterval) {
                Text("Never").tag(TimeInterval(0))
                Text("5 minutes").tag(TimeInterval(300))
                Text("15 minutes").tag(TimeInterval(900))
                Text("30 minutes").tag(TimeInterval(1800))
                Text("1 hour").tag(TimeInterval(3600))
            }

            Toggle(isOn: $settings.refreshOnWake) {
                Label("Refresh on Wake", systemImage: "sunrise")
            }

            Toggle(isOn: $settings.refreshOnNetworkReconnect) {
                Label("Refresh on Network Change", systemImage: "wifi")
            }

            Toggle(isOn: $settings.refreshOnHAReconnect) {
                Label("Refresh on HA Reconnect", systemImage: "server.rack")
            }
        } header: {
            Text("Refresh")
        } footer: {
            Text("Periodic refresh reloads the dashboard on a schedule. Other options refresh only when specific events occur.")
        }
    }

    // MARK: - Brightness Section

    private var brightnessSection: some View {
        Section {
            Toggle(isOn: $settings.brightnessControlEnabled) {
                Label("Manage Brightness", systemImage: "sun.max")
            }

            if settings.brightnessControlEnabled {
                VStack(alignment: .leading) {
                    Text("Brightness: \(Int(settings.manualBrightness * 100))%")
                    Slider(value: $settings.manualBrightness, in: 0.05...1.0)
                }

                Toggle(isOn: $settings.brightnessScheduleEnabled) {
                    Label("Use Schedule", systemImage: "clock")
                }

                if settings.brightnessScheduleEnabled {
                    HStack {
                        Text("Day")
                        Spacer()
                        Text("\(Int(settings.dayBrightness * 100))%")
                        Slider(value: $settings.dayBrightness, in: 0.05...1.0)
                            .frame(width: 100)
                    }

                    DatePicker("Day Starts", selection: Binding(
                        get: { dateFromTimeOfDay(settings.dayStartTime) },
                        set: { settings.dayStartTime = timeOfDayFromDate($0) }
                    ), displayedComponents: .hourAndMinute)

                    HStack {
                        Text("Night")
                        Spacer()
                        Text("\(Int(settings.nightBrightness * 100))%")
                        Slider(value: $settings.nightBrightness, in: 0.05...1.0)
                            .frame(width: 100)
                    }

                    DatePicker("Night Starts", selection: Binding(
                        get: { dateFromTimeOfDay(settings.nightStartTime) },
                        set: { settings.nightStartTime = timeOfDayFromDate($0) }
                    ), displayedComponents: .hourAndMinute)
                }
            }
        } header: {
            Text("Brightness")
        }
    }

    // MARK: - Screensaver Section

    private var screensaverSection: some View {
        Section {
            Toggle(isOn: $settings.screensaverEnabled) {
                Label("Enable Screensaver", systemImage: "moon.stars")
            }

            if settings.screensaverEnabled {
                Picker("Mode", selection: $settings.screensaverMode) {
                    ForEach(ScreensaverMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                Stepper(value: $settings.screensaverTimeout, in: 30...3600, step: 30) {
                    Label("Timeout: \(formatDuration(settings.screensaverTimeout))", systemImage: "timer")
                }

                if settings.screensaverMode == .dim {
                    VStack(alignment: .leading) {
                        Text("Dim Level: \(Int(settings.screensaverDimLevel * 100))%")
                        Slider(value: $settings.screensaverDimLevel, in: 0.01...0.5)
                    }
                }

                Button {
                    showingScreensaverConfig = true
                } label: {
                    Label("Screensaver Options", systemImage: "slider.horizontal.3")
                }

                Toggle(isOn: $settings.pixelShiftEnabled) {
                    Label("Pixel Shift (Burn-in Prevention)", systemImage: "arrow.up.left.and.arrow.down.right")
                }
            }
        } header: {
            Text("Screensaver")
        }
    }

    // MARK: - Triggers Section

    private var triggersSection: some View {
        Section {
            Toggle(isOn: $settings.wakeOnTouch) {
                Label("Wake on Touch", systemImage: "hand.tap")
            }

            Button {
                showingEntityTriggers = true
            } label: {
                HStack {
                    Label("Entity Triggers", systemImage: "bolt")
                    Spacer()
                    let count = settings.wakeEntities.count + settings.sleepEntities.count + settings.entityTriggers.count
                    Text("\(count)")
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Wake & Sleep Triggers")
        } footer: {
            Text("Configure external motion sensors or other HA entities to wake or sleep the display.")
        }
    }

    // MARK: - Presence Section

    private var presenceSection: some View {
        Section {
            Toggle(isOn: $settings.cameraMotionEnabled) {
                Label("Camera Motion Detection", systemImage: "camera.viewfinder")
            }

            if settings.cameraMotionEnabled {
                Toggle(isOn: $settings.wakeOnCameraMotion) {
                    Label("Wake on Motion", systemImage: "sunrise")
                }

                Picker("Sensitivity", selection: $settings.cameraMotionSensitivity) {
                    ForEach(MotionSensitivity.allCases, id: \.self) { sensitivity in
                        Text(sensitivity.displayName).tag(sensitivity)
                    }
                }

                Toggle(isOn: $settings.reportMotionToHA) {
                    Label("Report to Home Assistant", systemImage: "arrow.up.circle")
                }
            }

            Toggle(isOn: $settings.cameraPresenceEnabled) {
                Label("Person Detection", systemImage: "person.fill.viewfinder")
            }

            if settings.cameraPresenceEnabled {
                Toggle(isOn: $settings.wakeOnCameraPresence) {
                    Label("Wake on Presence", systemImage: "sunrise")
                }

                Toggle(isOn: $settings.cameraFaceDetectionEnabled) {
                    Label("Use Face Detection", systemImage: "face.smiling")
                }

                Toggle(isOn: $settings.reportPresenceToHA) {
                    Label("Report to Home Assistant", systemImage: "arrow.up.circle")
                }
            }
        } header: {
            Text("Camera & Presence")
        } footer: {
            Text("Motion and presence detection uses the front camera. All processing is done on-device.")
        }
    }

    // MARK: - Camera Popup Section

    private var cameraPopupSection: some View {
        Section {
            Picker("Popup Size", selection: $settings.cameraPopupSize) {
                ForEach(CameraPopupSize.allCases, id: \.self) { size in
                    Text(size.displayName).tag(size)
                }
            }

            Picker("Popup Position", selection: $settings.cameraPopupPosition) {
                ForEach(CameraPopupPosition.allCases, id: \.self) { position in
                    Text(position.displayName).tag(position)
                }
            }
        } header: {
            Text("Camera Popup")
        } footer: {
            Text("Configure how doorbell and security camera popups appear when triggered by notifications.")
        }
    }

    // MARK: - Audio Section

    private var audioSection: some View {
        Section {
            Toggle(isOn: $settings.ttsEnabled) {
                Label("Text-to-Speech", systemImage: "speaker.wave.3")
            }

            if settings.ttsEnabled {
                VStack(alignment: .leading) {
                    Text("TTS Volume: \(Int(settings.ttsVolume * 100))%")
                    Slider(value: $settings.ttsVolume, in: 0...1)
                }
            }

            Toggle(isOn: $settings.audioAlertsEnabled) {
                Label("Audio Alerts", systemImage: "bell.badge")
            }
        } header: {
            Text("Audio")
        }
    }

    // MARK: - Device Section

    private var deviceSection: some View {
        Section {
            Picker("Orientation Lock", selection: $settings.orientationLock) {
                ForEach(OrientationLock.allCases, id: \.self) { orientation in
                    Text(orientation.displayName).tag(orientation)
                }
            }

            Toggle(isOn: $settings.tamperDetectionEnabled) {
                Label("Tamper Detection", systemImage: "shield.checkered")
            }

            Toggle(isOn: $settings.touchHapticEnabled) {
                Label("Haptic Feedback", systemImage: "hand.point.up.braille")
            }

            Toggle(isOn: $settings.touchSoundEnabled) {
                Label("Touch Sounds", systemImage: "speaker.wave.1")
            }

            if settings.lowBatteryAlertThreshold > 0 {
                Stepper(value: $settings.lowBatteryAlertThreshold, in: 0...50, step: 5) {
                    Label("Low Battery Alert: \(settings.lowBatteryAlertThreshold)%", systemImage: "battery.25percent")
                }
            } else {
                Toggle(isOn: Binding(
                    get: { settings.lowBatteryAlertThreshold > 0 },
                    set: { settings.lowBatteryAlertThreshold = $0 ? 20 : 0 }
                )) {
                    Label("Low Battery Alerts", systemImage: "battery.25percent")
                }
            }
        } header: {
            Text("Device")
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else {
            return "\(Int(seconds / 3600))h"
        }
    }

    private func dateFromTimeOfDay(_ time: TimeOfDay) -> Date {
        var components = DateComponents()
        components.hour = time.hour
        components.minute = time.minute
        return Calendar.current.date(from: components) ?? Date()
    }

    private func timeOfDayFromDate(_ date: Date) -> TimeOfDay {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return TimeOfDay(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }

    // MARK: - Kiosk Exit Logic

    /// Attempt to exit kiosk mode with proper authentication fallback chain
    private func attemptKioskExit() {
        // Check if any authentication method is actually available
        let hasDevicePasscode = SecurityManager.shared.isDevicePasscodeSet
        let hasBiometric = settings.allowBiometricExit && SecurityManager.shared.isBiometryAvailable
        let hasPIN = !settings.exitPIN.isEmpty

        // If device passcode exit is enabled and available, use it
        if settings.allowDevicePasscodeExit && hasDevicePasscode {
            Task {
                let result = await SecurityManager.shared.authenticateWithDevicePasscode(
                    reason: "Exit kiosk mode"
                )
                await MainActor.run {
                    if result.success {
                        manager.disableKioskMode()
                    } else if let error = result.error {
                        authErrorMessage = error
                        showingAuthError = true
                    }
                    // If user cancelled (no error), do nothing - they can try again
                }
            }
            return
        }

        // If device passcode is enabled but not set, fall back to other methods
        if settings.allowDevicePasscodeExit && !hasDevicePasscode {
            // Fall through to try PIN or biometric
            if hasPIN {
                showingPINEntry = true
                return
            } else if hasBiometric {
                Task {
                    let success = await SecurityManager.shared.authenticate(reason: "Exit kiosk mode")
                    if success {
                        await MainActor.run {
                            manager.disableKioskMode()
                        }
                    }
                }
                return
            }
            // No other auth available - show error but allow exit anyway
            // (the user enabled device passcode but hasn't set one)
            authErrorMessage = "Device passcode is not set. Please configure a passcode in iOS Settings for better security."
            showingAuthError = true
            manager.disableKioskMode()
            return
        }

        // Custom PIN is set - show PIN entry
        if hasPIN {
            showingPINEntry = true
            return
        }

        // No PIN, try biometric if available
        if hasBiometric {
            Task {
                let success = await SecurityManager.shared.authenticate(reason: "Exit kiosk mode")
                if success {
                    await MainActor.run {
                        manager.disableKioskMode()
                    }
                }
            }
            return
        }

        // No authentication configured - just exit
        manager.disableKioskMode()
    }
}

// MARK: - PIN Setup View

struct PINSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var currentPIN: String
    @State private var newPIN: String = ""
    @State private var confirmPIN: String = ""
    @State private var showError = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("Enter PIN", text: $newPIN)
                        .keyboardType(.numberPad)

                    if !newPIN.isEmpty {
                        SecureField("Confirm PIN", text: $confirmPIN)
                            .keyboardType(.numberPad)
                    }
                } header: {
                    Text("Set Exit PIN")
                } footer: {
                    if showError {
                        Text("PINs do not match")
                            .foregroundColor(.red)
                    } else if newPIN.isEmpty {
                        Text("Leave empty to disable PIN protection")
                    }
                }

                if !currentPIN.isEmpty {
                    Section {
                        Button(role: .destructive) {
                            currentPIN = ""
                            dismiss()
                        } label: {
                            Text("Remove PIN")
                        }
                    }
                }
            }
            .navigationTitle("Exit PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if newPIN.isEmpty || newPIN == confirmPIN {
                            currentPIN = newPIN
                            dismiss()
                        } else {
                            showError = true
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    NavigationView {
        KioskSettingsView()
    }
}
