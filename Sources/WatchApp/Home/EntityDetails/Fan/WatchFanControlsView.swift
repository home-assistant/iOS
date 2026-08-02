import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

/// Controls screen a fan row pushes when its body is tapped: power and speed. Fans without speed
/// support never get here; their row toggles directly. Pushed through the home screen's
/// `NavigationStack`, like the light controls.
struct WatchFanControlsView: View {
    @StateObject private var viewModel: WatchFanControlsViewModel

    /// The view model is built inside `StateObject`'s autoclosure, so creation (and its poller)
    /// is deferred until the screen is actually pushed.
    init(item: MagicItem, itemInfo: MagicItem.Info, initialEntity: HAEntity? = nil) {
        self._viewModel = .init(
            wrappedValue: WatchFanControlsViewModel(item: item, itemInfo: itemInfo, initialEntity: initialEntity)
        )
    }

    var body: some View {
        List {
            header
            if viewModel.isStale {
                staleWarning
            }
            // No controls until the first snapshot: a toggle rendered before the state is known
            // would show "off" for a fan that may well be on.
            if viewModel.entity != nil {
                Section {
                    Toggle(isOn: powerBinding) {
                        Text(verbatim: L10n.Watch.FanControls.power)
                    }
                }
            }
            if viewModel.capabilities?.supportsSpeedPercentage == true {
                speedSection
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

    private var speedSection: some View {
        Section {
            VStack(spacing: DesignSystem.Spaces.half) {
                WatchGradientSlider(
                    value: speedBinding,
                    range: 0 ... 100,
                    gradient: [Color(uiColor: .init(hex: "#1A1A1A")), .white]
                )
                Text(verbatim: "\(Int(viewModel.speedPercentage))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
        } header: {
            Text(verbatim: L10n.Watch.FanControls.speed)
        }
    }

    private var powerBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isOn },
            set: { viewModel.setPower($0) }
        )
    }

    /// Snaps to the fan's reported speed granularity — many fans only do e.g. 25/50/75/100.
    private var speedBinding: Binding<Double> {
        Binding(
            get: { viewModel.speedPercentage },
            set: { value in
                let step = viewModel.speedStep
                let snapped = (value / step).rounded() * step
                viewModel.setSpeed(min(max(snapped, 0), 100))
            }
        )
    }
}

#Preview {
    MaterialDesignIcons.register()
    let item = MagicItem(id: "fan.bedroom", serverId: "1", type: .entity)
    let info = MagicItem.Info(
        id: "1-fan.bedroom",
        name: "Bedroom fan",
        iconName: "mdi:fan"
    )
    let entity = try? HAEntity(
        entityId: "fan.bedroom",
        state: "on",
        lastChanged: Date(timeIntervalSinceNow: -600),
        lastUpdated: Date(timeIntervalSinceNow: -60),
        attributes: [
            "friendly_name": "Bedroom fan",
            "supported_features": 1,
            "percentage": 50,
            "percentage_step": 25,
        ],
        context: .init(id: "", userId: "", parentId: "")
    )
    // In the app this screen is pushed by a row inside the home's NavigationStack.
    return NavigationStack {
        WatchFanControlsView(item: item, itemInfo: info, initialEntity: entity)
    }
}
