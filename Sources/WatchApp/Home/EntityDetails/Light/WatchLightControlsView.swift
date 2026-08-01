import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

/// Controls screen a light row pushes when its body is tapped: power, brightness and — when the
/// light supports it — color temperature. Lights without any of these capabilities never get
/// here; their row toggles directly. Pushed (not presented modally) to honor the row's chevron,
/// so it relies on the home screen's `NavigationStack` for the bar and back button.
struct WatchLightControlsView: View {
    @StateObject private var viewModel: WatchLightControlsViewModel

    /// The view model is built inside `StateObject`'s autoclosure so a `NavigationLink` can hold
    /// this view without instantiating a poller per row render — creation is deferred until the
    /// screen is actually pushed.
    init(item: MagicItem, itemInfo: MagicItem.Info, initialEntity: HAEntity? = nil) {
        self._viewModel = .init(
            wrappedValue: WatchLightControlsViewModel(item: item, itemInfo: itemInfo, initialEntity: initialEntity)
        )
    }

    var body: some View {
        List {
            header
            if viewModel.isStale {
                staleWarning
            }
            // No controls until the first snapshot: a toggle rendered before the state is known
            // would show "off" for a light that may well be on.
            if viewModel.entity != nil {
                Section {
                    Toggle(isOn: powerBinding) {
                        Text(verbatim: L10n.Watch.LightControls.power)
                    }
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
                } else {
                    // Pushed before the first state fetch answers — the controls appear as soon
                    // as the entity's capabilities are known.
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
                WatchGradientSlider(
                    value: brightnessBinding,
                    range: 0 ... 100,
                    gradient: [Color(uiColor: .init(hex: "#1A1A1A")), .white]
                )
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
                // Warm-to-cool, matching how Home Assistant's frontend paints the same control.
                WatchGradientSlider(
                    value: colorTempBinding,
                    range: viewModel.colorTempRange,
                    gradient: [
                        Color(uiColor: .init(hex: "#FFA757")),
                        .white,
                        Color(uiColor: .init(hex: "#BFDDFF")),
                    ]
                )
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
    // In the app this screen is pushed by a row inside the home's NavigationStack.
    return NavigationStack {
        WatchLightControlsView(item: item, itemInfo: info, initialEntity: entity)
    }
}
