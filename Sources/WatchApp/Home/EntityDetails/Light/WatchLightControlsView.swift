import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

/// Controls screen a light row opens when tapped: power, brightness and — when the light supports
/// it — color temperature. Lights without any of these capabilities never get here; their row
/// toggles directly.
struct WatchLightControlsView: View {
    @StateObject private var viewModel: WatchLightControlsViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: WatchLightControlsViewModel) {
        self._viewModel = .init(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            List {
                header
                if viewModel.isStale {
                    staleWarning
                }
                Section {
                    Toggle(isOn: powerBinding) {
                        Text(verbatim: L10n.Watch.LightControls.power)
                    }
                }
                if viewModel.capabilities?.supportsBrightness == true {
                    brightnessSection
                }
                if viewModel.capabilities?.supportsColorTemp == true {
                    colorTempSection
                }
            }
            .navigationTitle(Text(verbatim: viewModel.name))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemSymbol: .xmark)
                    }
                }
            }
        }
        .onAppear {
            viewModel.startStateUpdates()
        }
        .onDisappear {
            viewModel.stopStateUpdates()
        }
    }

    private var header: some View {
        Section {
            VStack(spacing: DesignSystem.Spaces.half) {
                Image(uiImage: viewModel.icon.image(
                    ofSize: .init(width: 24, height: 24),
                    color: viewModel.iconColor
                ))
                .watchRowIconContainer(color: viewModel.iconColor)
                if let stateText = viewModel.stateText {
                    Text(verbatim: stateText)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    private var staleWarning: some View {
        Label {
            Text(verbatim: L10n.Watch.EntityDetails.stale)
                .font(.caption2)
        } icon: {
            Image(systemSymbol: .exclamationmarkCircleFill)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.black, .orange)
        }
    }

    private var brightnessSection: some View {
        Section {
            VStack(spacing: DesignSystem.Spaces.half) {
                Slider(value: brightnessBinding, in: 0 ... 100, step: 10)
                Text(verbatim: "\(Int(viewModel.brightnessPercentage))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
        } header: {
            Text(verbatim: L10n.Watch.LightControls.brightness)
        }
    }

    private var colorTempSection: some View {
        Section {
            VStack(spacing: DesignSystem.Spaces.half) {
                Slider(value: colorTempBinding, in: viewModel.colorTempRange, step: 100)
                Text(verbatim: "\(Int(viewModel.colorTempKelvin)) K")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
        } header: {
            Text(verbatim: L10n.Watch.LightControls.temperature)
        }
    }

    private var powerBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isOn },
            set: { viewModel.setPower($0) }
        )
    }

    private var brightnessBinding: Binding<Double> {
        Binding(
            get: { viewModel.brightnessPercentage },
            set: { viewModel.setBrightness($0) }
        )
    }

    private var colorTempBinding: Binding<Double> {
        Binding(
            get: { viewModel.colorTempKelvin },
            set: { viewModel.setColorTemp($0) }
        )
    }
}

#Preview {
    MaterialDesignIcons.register()
    let item = MagicItem(id: "light.living_room", serverId: "1", type: .entity)
    let info = MagicItem.Info(
        id: "1-light.living_room",
        name: "Living room",
        iconName: "mdi:lightbulb"
    )
    let entity = try? HAEntity(
        entityId: "light.living_room",
        state: "on",
        lastChanged: Date(timeIntervalSinceNow: -600),
        lastUpdated: Date(timeIntervalSinceNow: -60),
        attributes: [
            "friendly_name": "Living room",
            "supported_color_modes": ["color_temp", "xy"],
            "brightness": 128,
            "color_temp_kelvin": 3200,
            "min_color_temp_kelvin": 2000,
            "max_color_temp_kelvin": 6500,
        ],
        context: .init(id: "", userId: "", parentId: "")
    )
    return WatchLightControlsView(viewModel: .init(item: item, itemInfo: info, initialEntity: entity))
}
