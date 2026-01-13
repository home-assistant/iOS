import LocalAuthentication
import SFSafeSymbols
import SwiftUI

// MARK: - Main Kiosk Settings View

/// Basic kiosk settings view for PR 1
/// Additional settings (dashboard rotation, entity triggers, camera) will be added in future PRs
public struct KioskSettingsView: View {
    @ObservedObject private var manager = KioskModeManager.shared
    @State private var settings: KioskSettings
    @State private var showingAuthentication = false
    @State private var showingAuthError = false
    @State private var authErrorMessage = ""

    public init() {
        _settings = State(initialValue: KioskModeManager.shared.settings)
    }

    public var body: some View {
        Form {
            kioskModeSection
            coreSettingsSection
            brightnessSection
            screensaverSection
            clockOptionsSection
        }
        .navigationTitle("Kiosk Mode")
        .onChange(of: settings) { newValue in
            manager.updateSettings(newValue)
        }
        .alert("Authentication Error", isPresented: $showingAuthError) {
            Button("OK", role: .cancel) {}
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
                        Image(systemSymbol: .lockFill)
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
                        Label("Exit Kiosk Mode", systemSymbol: .lockOpen)
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
                    Label("Enable Kiosk Mode", systemSymbol: .lock)
                }
            }
        } header: {
            Text("Kiosk Mode")
        } footer: {
            if !manager.isKioskModeActive {
                Text(
                    "When enabled, the display will be locked to the dashboard. Use Face ID, Touch ID, or device passcode to exit."
                )
            }
        }
    }

    // MARK: - Core Settings Section

    private var coreSettingsSection: some View {
        Section {
            Toggle(isOn: $settings.allowBiometricExit) {
                Label("Allow Face ID / Touch ID", systemSymbol: .faceid)
            }

            Toggle(isOn: $settings.allowDevicePasscodeExit) {
                Label("Allow Device Passcode", systemSymbol: .lockShield)
            }

            Toggle(isOn: $settings.navigationLockdown) {
                Label("Lock Navigation", systemSymbol: .handRaised)
            }

            Toggle(isOn: $settings.hideStatusBar) {
                Label("Hide Status Bar", systemSymbol: .rectangleExpandVertical)
            }

            Toggle(isOn: $settings.preventAutoLock) {
                Label("Prevent Auto-Lock", systemSymbol: .lockOpenDisplay)
            }

            Toggle(isOn: $settings.wakeOnTouch) {
                Label("Wake on Touch", systemSymbol: .handTap)
            }

            // Secret Exit Gesture
            Toggle(isOn: $settings.secretExitGestureEnabled) {
                Label("Secret Exit Gesture", systemSymbol: .handTap)
            }

            if settings.secretExitGestureEnabled {
                Picker("Exit Gesture Corner", selection: $settings.secretExitGestureCorner) {
                    ForEach(ScreenCorner.allCases, id: \.self) { corner in
                        Text(corner.displayName).tag(corner)
                    }
                }

                Stepper(value: $settings.secretExitGestureTaps, in: 2 ... 5) {
                    Label("Taps Required: \(settings.secretExitGestureTaps)", systemSymbol: .number)
                }
            }
        } header: {
            Text("Security & Display")
        } footer: {
            if settings.secretExitGestureEnabled {
                Text(
                    "Tap the \(settings.secretExitGestureCorner.displayName.lowercased()) corner \(settings.secretExitGestureTaps) times to access kiosk settings when locked."
                )
            }
        }
    }

    // MARK: - Brightness Section

    private var brightnessSection: some View {
        Section {
            Toggle(isOn: $settings.brightnessControlEnabled) {
                Label("Brightness Control", systemSymbol: .sunMax)
            }

            if settings.brightnessControlEnabled {
                VStack(alignment: .leading) {
                    Text("Manual Brightness: \(Int(settings.manualBrightness * 100))%")
                        .font(.caption)
                    Slider(value: $settings.manualBrightness, in: 0.1 ... 1.0, step: 0.05)
                }

                Toggle(isOn: $settings.brightnessScheduleEnabled) {
                    Label("Day/Night Schedule", systemSymbol: .clock)
                }

                if settings.brightnessScheduleEnabled {
                    VStack(alignment: .leading) {
                        Text("Day Brightness: \(Int(settings.dayBrightness * 100))%")
                            .font(.caption)
                        Slider(value: $settings.dayBrightness, in: 0.1 ... 1.0, step: 0.05)
                    }

                    VStack(alignment: .leading) {
                        Text("Night Brightness: \(Int(settings.nightBrightness * 100))%")
                            .font(.caption)
                        Slider(value: $settings.nightBrightness, in: 0.05 ... 1.0, step: 0.05)
                    }

                    HStack {
                        Text("Day starts")
                        Spacer()
                        TimeOfDayPicker(time: $settings.dayStartTime)
                    }

                    HStack {
                        Text("Night starts")
                        Spacer()
                        TimeOfDayPicker(time: $settings.nightStartTime)
                    }
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
                Label("Screensaver", systemSymbol: .moonStars)
            }

            if settings.screensaverEnabled {
                // For PR 1, only basic modes are fully supported
                Picker("Mode", selection: $settings.screensaverMode) {
                    Text("Clock").tag(ScreensaverMode.clock)
                    Text("Dim").tag(ScreensaverMode.dim)
                    Text("Blank").tag(ScreensaverMode.blank)
                }

                HStack {
                    Text("Timeout")
                    Spacer()
                    Picker("", selection: $settings.screensaverTimeout) {
                        Text("1 minute").tag(TimeInterval(60))
                        Text("2 minutes").tag(TimeInterval(120))
                        Text("5 minutes").tag(TimeInterval(300))
                        Text("10 minutes").tag(TimeInterval(600))
                        Text("15 minutes").tag(TimeInterval(900))
                        Text("30 minutes").tag(TimeInterval(1800))
                    }
                    .labelsHidden()
                }

                VStack(alignment: .leading) {
                    Text("Dim Level: \(Int(settings.screensaverDimLevel * 100))%")
                        .font(.caption)
                    Slider(value: $settings.screensaverDimLevel, in: 0.01 ... 0.5, step: 0.01)
                }

                Toggle(isOn: $settings.pixelShiftEnabled) {
                    Label("Pixel Shift (OLED)", systemSymbol: .arrowLeftArrowRight)
                }
            }
        } header: {
            Text("Screensaver")
        } footer: {
            Text("Pixel shift helps prevent burn-in on OLED displays by slightly moving content periodically.")
        }
    }

    // MARK: - Clock Options Section

    private var clockOptionsSection: some View {
        Section {
            Picker("Clock Style", selection: $settings.clockStyle) {
                ForEach(ClockStyle.allCases, id: \.self) { style in
                    Text(style.displayName).tag(style)
                }
            }

            Toggle(isOn: $settings.clockShowDate) {
                Label("Show Date", systemSymbol: .calendar)
            }

            Toggle(isOn: $settings.clockShowSeconds) {
                Label("Show Seconds", systemSymbol: .clock)
            }

            Toggle(isOn: $settings.clockUse24HourFormat) {
                Label("24-Hour Format", systemSymbol: .clock)
            }
        } header: {
            Text("Clock Display")
        }
    }

    // MARK: - Authentication

    private func attemptKioskExit() {
        let context = LAContext()
        var error: NSError?

        // Check what authentication methods are available
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Authenticate to exit kiosk mode"

            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        manager.disableKioskMode()
                    } else if let authError = authError as? LAError {
                        switch authError.code {
                        case .userCancel, .appCancel:
                            // User cancelled, do nothing
                            break
                        case .userFallback:
                            // User chose to use passcode
                            break
                        default:
                            authErrorMessage = authError.localizedDescription
                            showingAuthError = true
                        }
                    }
                }
            }
        } else {
            // No authentication available, just exit
            manager.disableKioskMode()
        }
    }
}

// MARK: - Time of Day Picker

struct TimeOfDayPicker: View {
    @Binding var time: TimeOfDay

    var body: some View {
        HStack {
            Picker("Hour", selection: $time.hour) {
                ForEach(0 ..< 24, id: \.self) { hour in
                    Text(String(format: "%02d", hour)).tag(hour)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 60)
            .clipped()

            Text(":")

            Picker("Minute", selection: $time.minute) {
                ForEach([0, 15, 30, 45], id: \.self) { minute in
                    Text(String(format: "%02d", minute)).tag(minute)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 60)
            .clipped()
        }
        .frame(height: 100)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        KioskSettingsView()
    }
}
