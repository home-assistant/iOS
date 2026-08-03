import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

/// Control screen a climate row pushes when tapped: the options the frontend's more-info dialog
/// offers (target temperature, HVAC mode, fan/swing/preset modes, humidity), each shown only when
/// the entity supports the capability. Pushed (not presented modally) to honor the row's chevron,
/// so it relies on the home screen's `NavigationStack` for the bar and back button.
struct WatchClimateControlView: View {
    @StateObject private var viewModel: WatchClimateControlViewModel

    /// The view model is built inside `StateObject`'s autoclosure, so creation (and its poller)
    /// is deferred until the screen is actually pushed.
    init(item: MagicItem, itemInfo: MagicItem.Info, initialEntity: HAEntity? = nil) {
        self._viewModel = .init(
            wrappedValue: WatchClimateControlViewModel(item: item, itemInfo: itemInfo, initialEntity: initialEntity)
        )
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: DesignSystem.Spaces.half) {
                    Image(uiImage: viewModel.icon.image(
                        ofSize: .init(width: 24, height: 24),
                        color: viewModel.iconColor
                    ))
                    .watchRowIconContainer(color: viewModel.iconColor)
                    if let control = viewModel.control {
                        if let currentTemperature = control.currentTemperature {
                            Text(verbatim: ClimateControlState.formatTemperature(currentTemperature))
                                .font(.title3.bold())
                                .minimumScaleFactor(0.6)
                        }
                        Text(verbatim: ClimateHvacMode.localizedTitle(forMode: control.hvacMode))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                            .progressViewStyle(.circular)
                        Text(verbatim: L10n.Watch.EntityDetails.loading)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            if viewModel.isStale {
                Label {
                    Text(verbatim: L10n.Watch.EntityDetails.stale)
                        .font(.caption2)
                } icon: {
                    Image(systemSymbol: .exclamationmarkCircleFill)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.black, .orange)
                }
            }
            if let control = viewModel.control {
                if control.supportsTargetTemperature {
                    Section {
                        HStack {
                            Button {
                                viewModel.adjustTargetTemperature(by: -1)
                            } label: {
                                Image(systemSymbol: .minus)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(Text(verbatim: L10n.Climate.Control.Temperature.decrease))
                            Text(
                                verbatim: control.targetTemperature
                                    .map(ClimateControlState.formatTemperature) ?? "—"
                            )
                            .font(.title3.bold())
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity)
                            Button {
                                viewModel.adjustTargetTemperature(by: 1)
                            } label: {
                                Image(systemSymbol: .plus)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(Text(verbatim: L10n.Climate.Control.Temperature.increase))
                        }
                        .listRowBackground(Color.clear)
                    } header: {
                        Text(verbatim: L10n.Climate.Control.Temperature.title)
                    }
                }
                if control.supportsTargetTemperatureRange {
                    Section {
                        HStack {
                            Button {
                                viewModel.adjustTargetTemperatureLow(by: -1)
                            } label: {
                                Image(systemSymbol: .minus)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(Text(verbatim: L10n.Climate.Control.Temperature.decrease))
                            Text(
                                verbatim: control.targetTemperatureLow
                                    .map(ClimateControlState.formatTemperature) ?? "—"
                            )
                            .font(.title3.bold())
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity)
                            Button {
                                viewModel.adjustTargetTemperatureLow(by: 1)
                            } label: {
                                Image(systemSymbol: .plus)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(Text(verbatim: L10n.Climate.Control.Temperature.increase))
                        }
                        .listRowBackground(Color.clear)
                    } header: {
                        Text(verbatim: L10n.Climate.Control.TemperatureLow.title)
                    }
                    Section {
                        HStack {
                            Button {
                                viewModel.adjustTargetTemperatureHigh(by: -1)
                            } label: {
                                Image(systemSymbol: .minus)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(Text(verbatim: L10n.Climate.Control.Temperature.decrease))
                            Text(
                                verbatim: control.targetTemperatureHigh
                                    .map(ClimateControlState.formatTemperature) ?? "—"
                            )
                            .font(.title3.bold())
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity)
                            Button {
                                viewModel.adjustTargetTemperatureHigh(by: 1)
                            } label: {
                                Image(systemSymbol: .plus)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(Text(verbatim: L10n.Climate.Control.Temperature.increase))
                        }
                        .listRowBackground(Color.clear)
                    } header: {
                        Text(verbatim: L10n.Climate.Control.TemperatureHigh.title)
                    }
                }
                if control.supportsHvacModes || control.supportsFanMode || control.supportsSwingMode ||
                    control.supportsSwingHorizontalMode || control.supportsPresetMode {
                    Section {
                        if control.supportsHvacModes {
                            NavigationLink {
                                WatchModeSelectionView(
                                    title: L10n.Climate.Control.Mode.title,
                                    options: control.hvacModes,
                                    selected: control.hvacMode,
                                    displayName: { ClimateHvacMode.localizedTitle(forMode: $0) },
                                    onSelect: { viewModel.setHvacMode($0) }
                                )
                            } label: {
                                HStack {
                                    Text(verbatim: L10n.Climate.Control.Mode.title)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(verbatim: ClimateHvacMode.localizedTitle(forMode: control.hvacMode))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        if control.supportsFanMode {
                            NavigationLink {
                                WatchModeSelectionView(
                                    title: L10n.Climate.Control.FanMode.title,
                                    options: control.fanModes,
                                    selected: control.fanMode,
                                    displayName: { ClimateControlState.displayName(forMode: $0) },
                                    onSelect: { viewModel.setFanMode($0) }
                                )
                            } label: {
                                HStack {
                                    Text(verbatim: L10n.Climate.Control.FanMode.title)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(
                                        verbatim: control.fanMode
                                            .map(ClimateControlState.displayName(forMode:)) ?? ""
                                    )
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                }
                            }
                        }
                        if control.supportsSwingMode {
                            NavigationLink {
                                WatchModeSelectionView(
                                    title: L10n.Climate.Control.SwingMode.title,
                                    options: control.swingModes,
                                    selected: control.swingMode,
                                    displayName: { ClimateControlState.displayName(forMode: $0) },
                                    onSelect: { viewModel.setSwingMode($0) }
                                )
                            } label: {
                                HStack {
                                    Text(verbatim: L10n.Climate.Control.SwingMode.title)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(
                                        verbatim: control.swingMode
                                            .map(ClimateControlState.displayName(forMode:)) ?? ""
                                    )
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                }
                            }
                        }
                        if control.supportsSwingHorizontalMode {
                            NavigationLink {
                                WatchModeSelectionView(
                                    title: L10n.Climate.Control.SwingHorizontalMode.title,
                                    options: control.swingHorizontalModes,
                                    selected: control.swingHorizontalMode,
                                    displayName: { ClimateControlState.displayName(forMode: $0) },
                                    onSelect: { viewModel.setSwingHorizontalMode($0) }
                                )
                            } label: {
                                HStack {
                                    Text(verbatim: L10n.Climate.Control.SwingHorizontalMode.title)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(
                                        verbatim: control.swingHorizontalMode
                                            .map(ClimateControlState.displayName(forMode:)) ?? ""
                                    )
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                }
                            }
                        }
                        if control.supportsPresetMode {
                            NavigationLink {
                                WatchModeSelectionView(
                                    title: L10n.Climate.Control.PresetMode.title,
                                    options: control.presetModes,
                                    selected: control.presetMode,
                                    displayName: { ClimateControlState.displayName(forMode: $0) },
                                    onSelect: { viewModel.setPresetMode($0) }
                                )
                            } label: {
                                HStack {
                                    Text(verbatim: L10n.Climate.Control.PresetMode.title)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(
                                        verbatim: control.presetMode
                                            .map(ClimateControlState.displayName(forMode:)) ?? ""
                                    )
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                }
                            }
                        }
                    } header: {
                        Text(verbatim: L10n.Climate.Control.Modes.title)
                    }
                }
                if control.supportsTargetHumidity {
                    Section {
                        HStack {
                            Button {
                                viewModel.adjustTargetHumidity(by: -1)
                            } label: {
                                Image(systemSymbol: .minus)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(Text(verbatim: L10n.Climate.Control.Humidity.decrease))
                            Text(
                                verbatim: control.targetHumidity
                                    .map(ClimateControlState.formatHumidity) ?? "—"
                            )
                            .font(.title3.bold())
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity)
                            Button {
                                viewModel.adjustTargetHumidity(by: 1)
                            } label: {
                                Image(systemSymbol: .plus)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(Text(verbatim: L10n.Climate.Control.Humidity.increase))
                        }
                        .listRowBackground(Color.clear)
                    } header: {
                        Text(verbatim: L10n.Climate.Control.Humidity.title)
                    }
                }
            }
        }
        .navigationTitle(Text(verbatim: viewModel.name))
        .alert(
            Text(verbatim: L10n.errorLabel),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button(role: .cancel) {} label: { Text(verbatim: L10n.okLabel) }
        } message: {
            Text(verbatim: viewModel.errorMessage ?? "")
        }
        .onAppear {
            viewModel.startStateUpdates()
        }
        .onDisappear {
            viewModel.stopStateUpdates()
        }
    }
}

#Preview {
    MaterialDesignIcons.register()
    let item = MagicItem(id: "climate.living_room", serverId: "1", type: .entity)
    let info = MagicItem.Info(
        id: "1-climate.living_room",
        name: "Living room thermostat",
        iconName: "mdi:thermostat"
    )
    let entity = try? HAEntity(
        entityId: "climate.living_room",
        state: "heat",
        lastChanged: Date(timeIntervalSinceNow: -600),
        lastUpdated: Date(timeIntervalSinceNow: -60),
        attributes: [
            "friendly_name": "Living room thermostat",
            "hvac_modes": ["off", "heat", "cool", "heat_cool"],
            "current_temperature": 20.4,
            "temperature": 21.5,
            "min_temp": 7,
            "max_temp": 35,
            "target_temp_step": 0.5,
            "fan_modes": ["auto", "low", "medium", "high"],
            "fan_mode": "auto",
            "preset_modes": ["home", "away", "eco"],
            "preset_mode": "home",
            "supported_features": 409,
        ],
        context: .init(id: "", userId: "", parentId: "")
    )
    return NavigationStack {
        WatchClimateControlView(item: item, itemInfo: info, initialEntity: entity)
    }
}
