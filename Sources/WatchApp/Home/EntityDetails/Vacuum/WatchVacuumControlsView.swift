import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

/// Controls screen a vacuum row pushes when tapped: start/pause, stop and return to dock, plus —
/// when the vacuum supports it — fan speed and locate. Vacuums have no single tap action, so
/// every tap on their row lands here. Pushed through the home screen's `NavigationStack`, like
/// the other entity controls.
struct WatchVacuumControlsView: View {
    @StateObject private var viewModel: WatchVacuumControlsViewModel

    /// The view model is built inside `StateObject`'s autoclosure, so creation (and its poller)
    /// is deferred until the screen is actually pushed.
    init(item: MagicItem, itemInfo: MagicItem.Info, initialEntity: HAEntity? = nil) {
        self._viewModel = .init(
            wrappedValue: WatchVacuumControlsViewModel(item: item, itemInfo: itemInfo, initialEntity: initialEntity)
        )
    }

    var body: some View {
        List {
            header
            if viewModel.isStale {
                staleWarning
            }
            // No controls until the first snapshot — capabilities are unknown, so the sections
            // would render empty next to the loading header.
            if viewModel.entity != nil {
                buttonsSection
                // Cleaning by area needs the phone to read the entity registry for us, so the
                // option only appears while it's reachable.
                if viewModel.capabilities?.supportsCleanArea == true, viewModel.isPhoneReachable {
                    cleanAreasSection
                }
                if viewModel.capabilities?.supportsFanSpeed == true {
                    fanSpeedSection
                }
                if viewModel.capabilities?.supportsLocate == true {
                    locateSection
                }
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
                    if let battery = viewModel.capabilities?.batteryLevel {
                        Text(verbatim: L10n.Vacuum.Control.battery("\(Int(battery))%"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
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

    /// Start (or pause while cleaning), stop and return to dock, shown only for the operations
    /// the vacuum reports.
    @ViewBuilder
    private var buttonsSection: some View {
        // The screen exists for every vacuum, so render whatever subset the entity supports.
        let capabilities = viewModel.capabilities
        Section {
            HStack(spacing: DesignSystem.Spaces.one) {
                if viewModel.isCleaning, capabilities?.supportsPause == true {
                    vacuumButton(symbol: .pauseFill, label: L10n.Vacuum.Control.pause) {
                        viewModel.pause()
                    }
                } else if capabilities?.supportsStart == true {
                    vacuumButton(symbol: .playFill, label: L10n.Vacuum.Control.start) {
                        viewModel.start()
                    }
                }
                if capabilities?.supportsStop == true {
                    vacuumButton(symbol: .stopFill, label: L10n.Vacuum.Control.stop) {
                        viewModel.stop()
                    }
                }
                if capabilities?.supportsReturnHome == true {
                    // Icon only: "Return to dock" is far too long to sit under a third-width
                    // button, and the house reads clearly on its own.
                    vacuumButton(symbol: .houseFill, label: nil, accessibilityLabel: L10n.Vacuum.Control.returnToBase) {
                        viewModel.returnToBase()
                    }
                }
            }
            .listRowBackground(Color.clear)
        }
    }

    private var cleanAreasSection: some View {
        Section {
            NavigationLink {
                WatchVacuumCleanAreasView(viewModel: viewModel)
            } label: {
                Label {
                    Text(verbatim: L10n.Vacuum.Control.CleanAreas.title)
                } icon: {
                    Image(systemSymbol: .squareGrid2x2)
                }
            }
        }
    }

    private var fanSpeedSection: some View {
        Section {
            NavigationLink {
                WatchModeSelectionView(
                    title: L10n.Vacuum.Control.FanSpeed.title,
                    options: viewModel.capabilities?.fanSpeedList ?? [],
                    selected: viewModel.capabilities?.fanSpeed,
                    displayName: { ClimateControlState.displayName(forMode: $0) },
                    onSelect: { viewModel.setFanSpeed($0) }
                )
            } label: {
                HStack {
                    Text(verbatim: L10n.Vacuum.Control.FanSpeed.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(
                        verbatim: viewModel.capabilities?.fanSpeed
                            .map(ClimateControlState.displayName(forMode:)) ?? ""
                    )
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
        }
    }

    private var locateSection: some View {
        Section {
            Button {
                viewModel.locate()
            } label: {
                Label {
                    Text(verbatim: L10n.Vacuum.Control.locate)
                } icon: {
                    Image(systemSymbol: .dotRadiowavesLeftAndRight)
                }
            }
        }
    }

    /// A `nil` label renders the icon alone — for commands whose name is too long to sit under a
    /// third-width button; `accessibilityLabel` then carries the name for VoiceOver.
    private func vacuumButton(
        symbol: SFSymbol,
        label: String?,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spaces.half) {
                Image(systemSymbol: symbol)
                    .font(.body.weight(.semibold))
                if let label {
                    Text(verbatim: label)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(maxWidth: .infinity)
        }
        // Explicit style, like the climate and cover controls: with the automatic one a `List` row
        // holding several buttons becomes a single tap target, so start/pause would also stop the
        // vacuum and send it back to its dock.
        .buttonStyle(.bordered)
        .accessibilityLabel(Text(verbatim: accessibilityLabel ?? label ?? ""))
    }
}

#Preview {
    MaterialDesignIcons.register()
    let item = MagicItem(id: "vacuum.downstairs", serverId: "1", type: .entity)
    let info = MagicItem.Info(
        id: "1-vacuum.downstairs",
        name: "Downstairs vacuum",
        iconName: "mdi:robot-vacuum"
    )
    let entity = try? HAEntity(
        entityId: "vacuum.downstairs",
        state: "cleaning",
        lastChanged: Date(timeIntervalSinceNow: -600),
        lastUpdated: Date(timeIntervalSinceNow: -60),
        attributes: [
            "friendly_name": "Downstairs vacuum",
            "supported_features": 8828,
            "battery_level": 80,
            "fan_speed": "medium",
            "fan_speed_list": ["quiet", "medium", "high", "max"],
        ],
        context: .init(id: "", userId: "", parentId: "")
    )
    // In the app this screen is pushed by a row inside the home's NavigationStack.
    return NavigationStack {
        WatchVacuumControlsView(item: item, itemInfo: info, initialEntity: entity)
    }
}
