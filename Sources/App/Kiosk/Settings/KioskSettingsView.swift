import LocalAuthentication
import SFSafeSymbols
import Shared
import SwiftUI

// MARK: - Main Kiosk Settings View

/// Kiosk settings view
/// TODO: Add dashboard rotation, entity triggers, and camera settings
public struct KioskSettingsView: View {
    @ObservedObject private var manager = KioskModeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var settings: KioskSettings
    @State private var isAuthenticated = false
    @State private var showingAuthError = false
    @State private var authErrorMessage = ""
    /// Captured at init time - whether auth is required to access settings
    /// This is set once and doesn't change even if settings are modified during the session
    @State private var authRequired: Bool

    public init() {
        let mgr = KioskModeManager.shared
        _settings = State(initialValue: mgr.settings)
        // Capture auth requirement at init time based on current kiosk state
        _authRequired = State(
            initialValue: mgr.isKioskModeActive && mgr.settings.requireDeviceAuthentication
        )
    }

    public var body: some View {
        Form {
            kioskModeSection
            coreSettingsSection
            brightnessSection
            screensaverSection
            clockOptionsSection
        }
        .navigationTitle(L10n.Kiosk.title)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.doneLabel) {
                    dismiss()
                }
            }
        }
        .disabled(authRequired && !isAuthenticated)
        .overlay {
            if authRequired, !isAuthenticated {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()

                    VStack(spacing: 20) {
                        Image(systemSymbol: .lockFill)
                            .font(.system(size: 48))
                            .foregroundColor(.white)

                        Text(L10n.Kiosk.Auth.required)
                            .font(.headline)
                            .foregroundColor(.white)

                        HStack(spacing: 16) {
                            Button {
                                dismiss()
                            } label: {
                                Text(L10n.cancelLabel)
                                    .frame(minWidth: 100)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                authenticateForSettings()
                            } label: {
                                Text(L10n.Kiosk.Auth.tryAgain)
                                    .frame(minWidth: 100)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(32)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .onAppear {
            // Pause screensaver idle timer while settings are open
            manager.pauseIdleTimer()

            if authRequired {
                // Delay auth prompt slightly to let the modal fully present
                // This prevents the auth dialog from dismissing the settings modal
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    authenticateForSettings()
                }
            } else {
                isAuthenticated = true
            }
        }
        .onDisappear {
            // Resume screensaver idle timer when settings are closed
            manager.resumeIdleTimer()
        }
        .onChange(of: settings) { newValue in
            if isAuthenticated || !authRequired {
                manager.updateSettings(newValue)
            }
        }
        .alert(L10n.Kiosk.AuthError.title, isPresented: $showingAuthError) {
            Button(L10n.okLabel, role: .cancel) {
                // Dismiss settings if auth failed while in kiosk mode
                if manager.isKioskModeActive {
                    dismiss()
                }
            }
        } message: {
            Text(authErrorMessage)
        }
    }

    // MARK: - Settings Authentication

    private func authenticateForSettings() {
        let context = LAContext()
        var error: NSError?
        let authSettings = manager.settings

        // No authentication required
        guard authSettings.requireDeviceAuthentication else {
            isAuthenticated = true
            return
        }

        // Use device owner authentication (Face ID/Touch ID with passcode fallback)
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No authentication available on device, allow access
            isAuthenticated = true
            return
        }

        let reason = L10n.Kiosk.AuthError.reason
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
            DispatchQueue.main.async {
                if success {
                    isAuthenticated = true
                } else if let authError = authError as? LAError {
                    switch authError.code {
                    case .userCancel, .appCancel:
                        // User cancelled - they can retry or close via overlay
                        break
                    default:
                        authErrorMessage = authError.localizedDescription
                        showingAuthError = true
                    }
                }
            }
        }
    }

    // MARK: - Kiosk Mode Section

    private var kioskModeSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { manager.isKioskModeActive },
                set: { newValue in
                    if newValue {
                        manager.enableKioskMode()
                    } else {
                        attemptKioskExit()
                    }
                }
            )) {
                Label(L10n.Kiosk.enableButton, systemSymbol: .lock)
            }
        } header: {
            Text(L10n.Kiosk.Section.title)
        } footer: {
            if !manager.isKioskModeActive {
                Text(L10n.Kiosk.Footer.description)
            }
        }
    }

    // MARK: - Core Settings Section

    private var coreSettingsSection: some View {
        Section {
            Toggle(isOn: $settings.requireDeviceAuthentication) {
                Label(L10n.Kiosk.Security.deviceAuth, systemSymbol: .lockShield)
            }

            Toggle(isOn: $settings.hideStatusBar) {
                Label(L10n.Kiosk.Security.hideStatusBar, systemSymbol: .rectangleExpandVertical)
            }

            Toggle(isOn: $settings.preventAutoLock) {
                Label(L10n.Kiosk.Security.preventAutolock, systemSymbol: .lockOpenDisplay)
            }

            Toggle(isOn: $settings.wakeOnTouch) {
                Label(L10n.Kiosk.Security.wakeOnTouch, systemSymbol: .handTap)
            }

            // Secret Exit Gesture
            Toggle(isOn: $settings.secretExitGestureEnabled) {
                Label(L10n.Kiosk.Security.secretGesture, systemSymbol: .handTap)
            }

            if settings.secretExitGestureEnabled {
                Picker(L10n.Kiosk.Security.gestureCorner, selection: $settings.secretExitGestureCorner) {
                    ForEach(ScreenCorner.allCases, id: \.self) { corner in
                        Text(corner.displayName).tag(corner)
                    }
                }

                Stepper(value: $settings.secretExitGestureTaps, in: 2 ... 5) {
                    Label(L10n.Kiosk.Security.tapsRequired(settings.secretExitGestureTaps), systemSymbol: .number)
                }
            }
        } header: {
            Text(L10n.Kiosk.Security.section)
        } footer: {
            if settings.secretExitGestureEnabled {
                Text(
                    L10n.Kiosk.Security.gestureFooter(
                        settings.secretExitGestureCorner.displayName.lowercased(),
                        settings.secretExitGestureTaps
                    )
                )
            }
        }
    }

    // MARK: - Brightness Section

    private var brightnessSection: some View {
        Section {
            Toggle(isOn: $settings.brightnessControlEnabled) {
                Label(L10n.Kiosk.Brightness.control, systemSymbol: .sunMax)
            }

            if settings.brightnessControlEnabled {
                VStack(alignment: .leading) {
                    Text(L10n.Kiosk.Brightness.manual(Int(settings.manualBrightness * 100)))
                        .font(.caption)
                    Slider(value: $settings.manualBrightness, in: 0.1 ... 1.0, step: 0.05)
                }

                Toggle(isOn: $settings.brightnessScheduleEnabled) {
                    Label(L10n.Kiosk.Brightness.schedule, systemSymbol: .clock)
                }

                if settings.brightnessScheduleEnabled {
                    VStack(alignment: .leading) {
                        Text(L10n.Kiosk.Brightness.day(Int(settings.dayBrightness * 100)))
                            .font(.caption)
                        Slider(value: $settings.dayBrightness, in: 0.1 ... 1.0, step: 0.05)
                    }

                    VStack(alignment: .leading) {
                        Text(L10n.Kiosk.Brightness.night(Int(settings.nightBrightness * 100)))
                            .font(.caption)
                        Slider(value: $settings.nightBrightness, in: 0.05 ... 1.0, step: 0.05)
                    }

                    HStack {
                        Text(L10n.Kiosk.Brightness.dayStarts)
                        Spacer()
                        TimeOfDayPicker(time: $settings.dayStartTime)
                    }

                    HStack {
                        Text(L10n.Kiosk.Brightness.nightStarts)
                        Spacer()
                        TimeOfDayPicker(time: $settings.nightStartTime)
                    }
                }
            }
        } header: {
            Text(L10n.Kiosk.Brightness.section)
        }
    }

    // MARK: - Screensaver Section

    private var screensaverSection: some View {
        Section {
            Toggle(isOn: $settings.screensaverEnabled) {
                Label(L10n.Kiosk.Screensaver.toggle, systemSymbol: .moonStars)
            }

            if settings.screensaverEnabled {
                // TODO: Add photo and custom URL screensaver modes
                Picker(L10n.Kiosk.Screensaver.mode, selection: $settings.screensaverMode) {
                    Text(L10n.Kiosk.Screensaver.Mode.clock).tag(ScreensaverMode.clock)
                    Text(L10n.Kiosk.Screensaver.Mode.dim).tag(ScreensaverMode.dim)
                    Text(L10n.Kiosk.Screensaver.Mode.blank).tag(ScreensaverMode.blank)
                }

                HStack {
                    Text(L10n.Kiosk.Screensaver.timeout)
                    Spacer()
                    Picker("", selection: $settings.screensaverTimeout) {
                        Text(L10n.Kiosk.Screensaver.Timeout._30sec).tag(TimeInterval(30))
                        Text(L10n.Kiosk.Screensaver.Timeout._1min).tag(TimeInterval(60))
                        Text(L10n.Kiosk.Screensaver.Timeout._2min).tag(TimeInterval(120))
                        Text(L10n.Kiosk.Screensaver.Timeout._5min).tag(TimeInterval(300))
                        Text(L10n.Kiosk.Screensaver.Timeout._10min).tag(TimeInterval(600))
                        Text(L10n.Kiosk.Screensaver.Timeout._15min).tag(TimeInterval(900))
                        Text(L10n.Kiosk.Screensaver.Timeout._30min).tag(TimeInterval(1800))
                    }
                    .labelsHidden()
                }

                VStack(alignment: .leading) {
                    Text(L10n.Kiosk.Screensaver.dimLevel(Int(settings.screensaverDimLevel * 100)))
                        .font(.caption)
                    Slider(value: $settings.screensaverDimLevel, in: 0.01 ... 0.5, step: 0.01)
                }

                Toggle(isOn: $settings.pixelShiftEnabled) {
                    Label(L10n.Kiosk.Screensaver.pixelShift, systemSymbol: .arrowLeftArrowRight)
                }
            }
        } header: {
            Text(L10n.Kiosk.Screensaver.section)
        } footer: {
            Text(L10n.Kiosk.Screensaver.pixelShiftFooter)
        }
    }

    // MARK: - Clock Options Section

    private var clockOptionsSection: some View {
        Section {
            Picker(L10n.Kiosk.Clock.style, selection: $settings.clockStyle) {
                ForEach(ClockStyle.allCases, id: \.self) { style in
                    Text(style.displayName).tag(style)
                }
            }

            Toggle(isOn: $settings.clockShowDate) {
                Label(L10n.Kiosk.Clock.showDate, systemSymbol: .calendar)
            }

            Toggle(isOn: $settings.clockShowSeconds) {
                Label(L10n.Kiosk.Clock.showSeconds, systemSymbol: .clock)
            }

            Toggle(isOn: $settings.clockUse24HourFormat) {
                Label(L10n.Kiosk.Clock._24hour, systemSymbol: .clock)
            }
        } header: {
            Text(L10n.Kiosk.Clock.section)
        }
    }

    // MARK: - Authentication

    private func attemptKioskExit() {
        // Use persisted settings for auth checks, not local copy
        // This prevents bypassing auth by disabling it in the form first
        let authSettings = manager.settings

        // If no authentication required, just exit
        guard authSettings.requireDeviceAuthentication else {
            manager.disableKioskMode()
            return
        }

        let context = LAContext()
        var error: NSError?

        // Use device owner authentication (Face ID/Touch ID with passcode fallback)
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No authentication available on device, allow exit
            manager.disableKioskMode()
            return
        }

        let reason = L10n.Kiosk.AuthError.reason
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
            DispatchQueue.main.async {
                if success {
                    manager.disableKioskMode()
                } else if let authError = authError as? LAError {
                    switch authError.code {
                    case .userCancel, .appCancel:
                        // User cancelled, do nothing
                        break
                    default:
                        authErrorMessage = authError.localizedDescription
                        showingAuthError = true
                    }
                }
            }
        }
    }
}

// MARK: - Time of Day Picker

struct TimeOfDayPicker: View {
    @Binding var time: TimeOfDay

    var body: some View {
        HStack {
            Picker(L10n.Kiosk.Time.hour, selection: $time.hour) {
                ForEach(0 ..< 24, id: \.self) { hour in
                    Text(String(format: "%02d", hour)).tag(hour)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 60)
            .clipped()

            Text(":")

            Picker(L10n.Kiosk.Time.minute, selection: $time.minute) {
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
