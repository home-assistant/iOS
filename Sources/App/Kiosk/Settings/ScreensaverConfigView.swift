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
        Group {
            Section {
                Toggle("Show Date", isOn: $settings.clockShowDate)

                Toggle("Show Seconds", isOn: $settings.clockShowSeconds)

                Toggle("Use 24-Hour Format", isOn: $settings.clockUse24HourFormat)

                Picker("Clock Style", selection: $settings.clockStyle) {
                    ForEach(ClockStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
            } header: {
                Text("Clock Options")
            }

            weatherSection

            if settings.screensaverMode == .clockWithEntities {
                clockEntitiesSection
            }
        }
    }

    // MARK: - Weather Section

    private var weatherSection: some View {
        Section {
            Toggle("Show Weather", isOn: $settings.clockShowWeather)

            if settings.clockShowWeather {
                NavigationLink {
                    EntityPickerView(
                        selectedEntityId: $settings.clockWeatherEntity,
                        domainFilter: ["weather"],
                        title: "Weather Entity"
                    )
                } label: {
                    HStack {
                        Text("Weather Entity")
                        Spacer()
                        Text(settings.clockWeatherEntity.isEmpty ? "Not Set" : friendlyEntityName(settings.clockWeatherEntity))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                NavigationLink {
                    EntityPickerView(
                        selectedEntityId: $settings.clockTemperatureEntity,
                        domainFilter: ["sensor"],
                        title: "Temperature Sensor"
                    )
                } label: {
                    HStack {
                        Text("Temperature Sensor")
                        Spacer()
                        Text(settings.clockTemperatureEntity.isEmpty ? "Optional" : friendlyEntityName(settings.clockTemperatureEntity))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        } header: {
            Text("Weather Display")
        } footer: {
            if settings.clockShowWeather {
                Text("Select a weather entity for conditions. Optionally select a temperature sensor for more accurate temperature display.")
            }
        }
    }

    // MARK: - Clock Entities Section

    private var clockEntitiesSection: some View {
        Section {
            ForEach($settings.clockEntities) { $entity in
                NavigationLink {
                    EntityPickerView(
                        selectedEntityId: $entity.entityId,
                        title: "Select Entity"
                    )
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entity.entityId.isEmpty ? "Tap to select" : friendlyEntityName(entity.entityId))
                                .foregroundColor(entity.entityId.isEmpty ? .secondary : .primary)
                            if !entity.entityId.isEmpty {
                                Text(entity.entityId)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Button {
                            settings.clockEntities.removeAll { $0.id == entity.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                settings.clockEntities.append(ClockEntityConfig(entityId: ""))
            } label: {
                Label("Add Entity", systemImage: "plus.circle")
            }
        } header: {
            Text("Display Entities")
        } footer: {
            Text("Add Home Assistant entities to display on the screensaver.")
        }
    }

    // MARK: - Helpers

    private func friendlyEntityName(_ entityId: String) -> String {
        // Extract a friendly name from entity ID (e.g., "sensor.living_room_temp" -> "Living Room Temp")
        guard !entityId.isEmpty else { return "" }
        let parts = entityId.components(separatedBy: ".")
        guard parts.count > 1 else { return entityId }
        return parts[1]
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    // MARK: - Photo Settings

    private var photoSettings: some View {
        Group {
            Section {
                Picker("Photo Source", selection: $settings.photoSource) {
                    ForEach(PhotoSource.allCases, id: \.self) { source in
                        Text(source.displayName).tag(source)
                    }
                }

                // Show album picker for local photos
                if settings.photoSource == .local || settings.photoSource == .all {
                    NavigationLink {
                        PhotoAlbumPickerView(
                            selectedAlbumIds: $settings.localPhotoAlbums,
                            albumType: .local,
                            title: "Local Albums"
                        )
                    } label: {
                        HStack {
                            Text("Local Albums")
                            Spacer()
                            Text(localAlbumSummary)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                // Show album picker for iCloud photos
                if settings.photoSource == .iCloud || settings.photoSource == .all {
                    NavigationLink {
                        PhotoAlbumPickerView(
                            selectedAlbumIds: $settings.iCloudAlbums,
                            albumType: .iCloud,
                            title: "iCloud Albums"
                        )
                    } label: {
                        HStack {
                            Text("iCloud Albums")
                            Spacer()
                            Text(iCloudAlbumSummary)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                // HA Media path for HA media source
                if settings.photoSource == .haMedia || settings.photoSource == .all {
                    TextField("HA Media Path", text: $settings.haMediaPath)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
            } header: {
                Text("Photo Source")
            } footer: {
                photoSourceFooter
            }

            Section {
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

                if settings.screensaverMode == .photosWithClock {
                    Toggle("Show Clock Overlay", isOn: $settings.photoShowClockOverlay)
                    Toggle("Show Entity Overlay", isOn: $settings.photoShowEntityOverlay)
                }
            } header: {
                Text("Display Options")
            }
        }
    }

    private var localAlbumSummary: String {
        if settings.localPhotoAlbums.isEmpty {
            return "None selected"
        } else if settings.localPhotoAlbums.contains("all_photos") {
            return "All Photos"
        } else {
            return "\(settings.localPhotoAlbums.count) album(s)"
        }
    }

    private var iCloudAlbumSummary: String {
        if settings.iCloudAlbums.isEmpty {
            return "None selected"
        } else if settings.iCloudAlbums.contains("all_photos") {
            return "All Photos"
        } else {
            return "\(settings.iCloudAlbums.count) album(s)"
        }
    }

    @ViewBuilder
    private var photoSourceFooter: some View {
        switch settings.photoSource {
        case .local:
            Text("Select albums from your device's photo library.")
        case .iCloud:
            Text("Select albums from iCloud Photos, including shared albums.")
        case .haMedia:
            Text("Enter a path in your Home Assistant media folder (e.g., /local/photos).")
        case .all:
            Text("Photos will be sourced from all configured locations.")
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
