import Shared
import SwiftUI

// MARK: - Screensaver Config View

/// Detailed screensaver configuration view
public struct ScreensaverConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var settings: KioskSettings

    public init(settings: Binding<KioskSettings>) {
        _settings = settings
    }

    public var body: some View {
        NavigationView {
            Form {
                // Mode Selection
                Section {
                    Picker("Screensaver Mode", selection: $settings.screensaverMode) {
                        ForEach(ScreensaverMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Mode")
                }

                // Mode-specific settings
                switch settings.screensaverMode {
                case .clock, .clockWithEntities:
                    clockSettings
                case .photos, .photosWithClock:
                    photoSettings
                case .dim:
                    dimSettings
                case .blank:
                    EmptyView()
                case .customURL:
                    customURLSettings
                }

                // Common settings
                commonSettings
            }
            .navigationTitle("Screensaver Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Clock Settings

    private var clockSettings: some View {
        Section {
            Toggle("Show Date", isOn: $settings.clockShowDate)

            Toggle("Show Seconds", isOn: $settings.clockShowSeconds)

            Toggle("Use 24-Hour Format", isOn: $settings.clockUse24HourFormat)

            Picker("Clock Style", selection: $settings.clockStyle) {
                ForEach(ClockStyle.allCases, id: \.self) { style in
                    Text(style.displayName).tag(style)
                }
            }

            if settings.screensaverMode == .clockWithEntities {
                clockEntitiesSection
            }
        } header: {
            Text("Clock Options")
        }
    }

    private var clockEntitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Display Entities")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach($settings.clockEntities) { $entity in
                HStack {
                    TextField("Entity ID", text: $entity.entityId)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    Button {
                        settings.clockEntities.removeAll { $0.id == entity.id }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }

            Button {
                settings.clockEntities.append(ClockEntityConfig(entityId: ""))
            } label: {
                Label("Add Entity", systemImage: "plus.circle")
            }
        }
    }

    // MARK: - Photo Settings

    private var photoSettings: some View {
        Section {
            Picker("Photo Source", selection: $settings.photoSource) {
                ForEach(PhotoSource.allCases, id: \.self) { source in
                    Text(source.displayName).tag(source)
                }
            }

            Stepper(value: $settings.photoInterval, in: 5...120, step: 5) {
                Text("Interval: \(Int(settings.photoInterval))s")
            }

            Picker("Transition Style", selection: $settings.photoTransition) {
                ForEach(PhotoTransition.allCases, id: \.self) { transition in
                    Text(transition.displayName).tag(transition)
                }
            }

            Picker("Fit Mode", selection: $settings.photoFitMode) {
                ForEach(PhotoFitMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            if settings.photoSource == .haMedia {
                TextField("HA Media Path", text: $settings.haMediaPath)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }

            if settings.screensaverMode == .photosWithClock {
                Toggle("Show Clock Overlay", isOn: $settings.photoShowClockOverlay)
                Toggle("Show Entity Overlay", isOn: $settings.photoShowEntityOverlay)
            }
        } header: {
            Text("Photo Options")
        }
    }

    // MARK: - Dim Settings

    private var dimSettings: some View {
        Section {
            Text("The screen will be dimmed to the brightness level set below.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        } header: {
            Text("Dim Mode")
        } footer: {
            Text("Dim mode shows a blank dimmed screen. Adjust brightness in the Brightness section below.")
        }
    }

    // MARK: - Custom URL Settings

    private var customURLSettings: some View {
        Section {
            TextField("Custom Dashboard URL", text: $settings.screensaverCustomURL)
                .autocapitalization(.none)
                .autocorrectionDisabled()
        } header: {
            Text("Custom URL")
        } footer: {
            Text("Enter a URL to a custom dashboard to display as the screensaver.")
        }
    }

    // MARK: - Common Settings

    private var commonSettings: some View {
        Group {
            brightnessSettings
            burnInSettings
        }
    }

    private var brightnessSettings: some View {
        Section {
            VStack(alignment: .leading) {
                Text("Dim Level: \(Int(settings.screensaverDimLevel * 100))%")
                Slider(value: $settings.screensaverDimLevel, in: 0.01...0.5)
            }

            Toggle("Day/Night Schedule", isOn: $settings.screensaverBrightnessScheduleEnabled)

            if settings.screensaverBrightnessScheduleEnabled {
                VStack(alignment: .leading) {
                    Text("Day Brightness: \(Int(settings.screensaverDayDimLevel * 100))%")
                    Slider(value: $settings.screensaverDayDimLevel, in: 0.01...0.5)
                }

                VStack(alignment: .leading) {
                    Text("Night Brightness: \(Int(settings.screensaverNightDimLevel * 100))%")
                    Slider(value: $settings.screensaverNightDimLevel, in: 0.01...0.3)
                }
            }
        } header: {
            Text("Brightness")
        } footer: {
            if settings.screensaverBrightnessScheduleEnabled {
                Text("Uses the same day/night schedule times as main brightness settings.")
            } else {
                Text("Adjust how dim the screen gets during screensaver.")
            }
        }
    }

    private var burnInSettings: some View {
        Section {
            Toggle("Pixel Shift", isOn: $settings.pixelShiftEnabled)

            if settings.pixelShiftEnabled {
                Stepper(value: $settings.pixelShiftInterval, in: 30...300, step: 30) {
                    Text("Shift Interval: \(Int(settings.pixelShiftInterval))s")
                }

                VStack(alignment: .leading) {
                    Text("Shift Amount: \(Int(settings.pixelShiftAmount))px")
                    Slider(value: $settings.pixelShiftAmount, in: 5...30)
                }
            }
        } header: {
            Text("Burn-in Prevention")
        } footer: {
            Text("Pixel shift periodically moves content to prevent screen burn-in.")
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    ScreensaverConfigView(settings: .constant(KioskSettings()))
}
