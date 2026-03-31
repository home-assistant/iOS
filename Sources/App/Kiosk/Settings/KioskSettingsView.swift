import SFSafeSymbols
import Shared
import SwiftUI

// MARK: - Main Kiosk Settings View

/// Kiosk settings view
public struct KioskSettingsView: View {
    @StateObject private var viewModel: KioskSettingsViewModel
    @Environment(\.dismiss) private var environmentDismiss

    /// Initialize with optional explicit dismiss closure
    /// - Parameter onDismiss: Closure called when the view should be dismissed.
    ///   If nil, uses SwiftUI's environment dismiss (for NavigationLink contexts).
    ///   Pass explicit closure when presenting via UIKit's UINavigationController.
    public init(onDismiss: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: KioskSettingsViewModel(onDismiss: onDismiss))
    }

    public var body: some View {
        Form {
            AppleLikeListTopRowHeader(
                image: .tabletDashboardIcon,
                title: L10n.Kiosk.title,
                subtitle: L10n.Kiosk.Footer.description
            )
            kioskModeSection
            coreSettingsSection
            brightnessSection
            screensaverSection
        }
        .navigationTitle(L10n.Kiosk.title)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.doneLabel) {
                    viewModel.dismiss(using: environmentDismiss)
                }
            }
        }
        .disabled(viewModel.authRequired && !viewModel.isAuthenticated)
        .overlay { authGateOverlay }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onChange(of: viewModel.settings) { _ in
            viewModel.settingsChanged()
        }
        .alert(L10n.Kiosk.AuthError.title, isPresented: $viewModel.showingAuthError) {
            Button(L10n.okLabel, role: .cancel) {
                viewModel.handleAuthErrorDismissed(using: environmentDismiss)
            }
        } message: {
            Text(viewModel.authErrorMessage)
        }
    }

    // MARK: - Auth Gate Overlay

    @ViewBuilder private var authGateOverlay: some View {
        if viewModel.authRequired, !viewModel.isAuthenticated {
            VStack(spacing: DesignSystem.Spaces.three) {
                Spacer()

                Image(systemSymbol: .lockFill)
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)

                Text(L10n.Kiosk.Auth.gateTitle)
                    .font(DesignSystem.Font.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text(L10n.Kiosk.Auth.gateDescription)
                    .font(DesignSystem.Font.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spaces.two)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: DesignSystem.Spaces.one) {
                    Button {
                        viewModel.authenticateForSettings()
                    } label: {
                        Text(L10n.Kiosk.Auth.authenticateButton)
                    }
                    .buttonStyle(.primaryButton)

                    Button {
                        viewModel.dismiss(using: environmentDismiss)
                    } label: {
                        Text(L10n.Kiosk.Auth.goBackButton)
                    }
                    .buttonStyle(.secondaryButton)
                    .tint(Color.haPrimary)
                }
                .padding([.horizontal, .top], DesignSystem.Spaces.two)
                .background(Color(uiColor: .systemBackground).opacity(0.95))
            }
            .background(Color(uiColor: .systemBackground))
        }
    }

    // MARK: - Kiosk Mode Section

    private var kioskModeSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { viewModel.isKioskModeActive },
                set: { newValue in
                    if newValue {
                        viewModel.enableKioskMode()
                    } else {
                        viewModel.attemptKioskExit()
                    }
                }
            )) {
                Label(L10n.Kiosk.enableButton, systemSymbol: .lock)
            }
        }
    }

    // MARK: - Core Settings Section

    private var coreSettingsSection: some View {
        Section {
            Toggle(isOn: $viewModel.settings.requireDeviceAuthentication) {
                Label(L10n.Kiosk.Security.deviceAuth, systemSymbol: .lockShield)
            }

            Toggle(isOn: $viewModel.settings.hideStatusBar) {
                Label(L10n.Kiosk.Security.hideStatusBar, systemSymbol: .rectangleExpandVertical)
            }

            Toggle(isOn: $viewModel.settings.preventAutoLock) {
                Label(L10n.Kiosk.Security.preventAutolock, systemSymbol: .lockOpenDisplay)
            }

            // Secret Exit Gesture
            Toggle(isOn: $viewModel.settings.secretExitGestureEnabled) {
                Label(L10n.Kiosk.Security.secretGesture, systemSymbol: .handTap)
            }

            if viewModel.settings.secretExitGestureEnabled {
                Picker(L10n.Kiosk.Security.gestureCorner, selection: $viewModel.settings.secretExitGestureCorner) {
                    ForEach(ScreenCorner.allCases, id: \.self) { corner in
                        Text(corner.displayName).tag(corner)
                    }
                }

                Stepper(
                    value: $viewModel.settings.secretExitGestureTaps,
                    in: 2 ... 5
                ) {
                    Label(
                        L10n.Kiosk.Security.tapsRequired(viewModel.settings.secretExitGestureTaps),
                        systemSymbol: .number
                    )
                }
            }
        } header: {
            Text(L10n.Kiosk.Security.section)
        } footer: {
            if viewModel.settings.secretExitGestureEnabled {
                Text(
                    L10n.Kiosk.Security.gestureFooter(
                        viewModel.settings.secretExitGestureCorner.displayName,
                        viewModel.settings.secretExitGestureTaps
                    )
                )
            }
        }
    }

    // MARK: - Brightness Section

    private var brightnessSection: some View {
        Section {
            Toggle(isOn: $viewModel.settings.brightnessControlEnabled) {
                Label(L10n.Kiosk.Brightness.control, systemSymbol: .sunMax)
            }

            if viewModel.settings.brightnessControlEnabled {
                VStack(alignment: .leading) {
                    Text(L10n.Kiosk.Brightness.manual(Int(viewModel.settings.manualBrightness * 100)))
                        .font(.caption)
                    Slider(value: $viewModel.settings.manualBrightness, in: 0.1 ... 1.0, step: 0.05)
                }
            }
        } header: {
            Text(L10n.Kiosk.Brightness.section)
        }
    }

    // MARK: - Screensaver Section

    private var screensaverSection: some View {
        Section {
            Toggle(isOn: $viewModel.settings.screensaverEnabled) {
                Label(L10n.Kiosk.Screensaver.toggle, systemSymbol: .moonStars)
            }

            if viewModel.settings.screensaverEnabled {
                Picker(L10n.Kiosk.Screensaver.mode, selection: $viewModel.settings.screensaverMode) {
                    Text(L10n.Kiosk.Screensaver.Mode.clock).tag(ScreensaverMode.clock)
                    Text(L10n.Kiosk.Screensaver.Mode.dim).tag(ScreensaverMode.dim)
                    Text(L10n.Kiosk.Screensaver.Mode.blank).tag(ScreensaverMode.blank)
                }

                HStack {
                    Text(L10n.Kiosk.Screensaver.timeout)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { ScreensaverTimeout(from: viewModel.settings.screensaverTimeout) },
                        set: { viewModel.settings.screensaverTimeout = $0.timeInterval }
                    )) {
                        ForEach(ScreensaverTimeout.allCases, id: \.self) { timeout in
                            Text(timeout.displayName).tag(timeout)
                        }
                    }
                    .labelsHidden()
                }

                VStack(alignment: .leading) {
                    Text(L10n.Kiosk.Screensaver.dimLevel(Int(viewModel.settings.screensaverDimLevel * 100)))
                        .font(.caption)
                    Slider(value: $viewModel.settings.screensaverDimLevel, in: 0.01 ... 0.5, step: 0.01)
                }

                Toggle(isOn: $viewModel.settings.pixelShiftEnabled) {
                    Label(L10n.Kiosk.Screensaver.pixelShift, systemSymbol: .arrowLeftArrowRight)
                }

                if viewModel.settings.screensaverMode == .clock {
                    Picker(L10n.Kiosk.Clock.style, selection: $viewModel.settings.clockStyle) {
                        ForEach(ClockStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }

                    Toggle(isOn: $viewModel.settings.clockShowDate) {
                        Label(L10n.Kiosk.Clock.showDate, systemSymbol: .calendar)
                    }

                    Toggle(isOn: $viewModel.settings.clockShowSeconds) {
                        Label(L10n.Kiosk.Clock.showSeconds, systemSymbol: .clock)
                    }

                    Toggle(isOn: $viewModel.settings.clockUse24HourFormat) {
                        Label(L10n.Kiosk.Clock._24hour, systemSymbol: .clock)
                    }
                }
            }
        } header: {
            Text(L10n.Kiosk.Screensaver.section)
        } footer: {
            Text(L10n.Kiosk.Screensaver.pixelShiftFooter)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        KioskSettingsView()
    }
}
