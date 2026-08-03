import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

/// Controls screen a cover row pushes when its body is tapped: a position slider (when the cover
/// supports positioning) and open/stop/close buttons. Covers without position or stop support
/// never get here; their row toggles directly. Pushed through the home screen's
/// `NavigationStack`, like the light controls.
struct WatchCoverControlsView: View {
    @StateObject private var viewModel: WatchCoverControlsViewModel

    /// The view model is built inside `StateObject`'s autoclosure, so creation (and its poller)
    /// is deferred until the screen is actually pushed.
    init(item: MagicItem, itemInfo: MagicItem.Info, initialEntity: HAEntity? = nil) {
        self._viewModel = .init(
            wrappedValue: WatchCoverControlsViewModel(item: item, itemInfo: itemInfo, initialEntity: initialEntity)
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
                if viewModel.capabilities?.supportsSetPosition == true {
                    positionSection
                }
                buttonsSection
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

    private var positionSection: some View {
        Section {
            VStack(spacing: DesignSystem.Spaces.half) {
                // Dark (closed) to light (open), matching the position scale.
                WatchGradientSlider(
                    value: positionBinding,
                    range: 0 ... 100,
                    gradient: [Color(uiColor: .init(hex: "#1A1A1A")), .white]
                )
                Text(verbatim: "\(Int(viewModel.position))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
        } header: {
            Text(verbatim: L10n.Watch.CoverControls.position)
        }
    }

    /// Open/stop/close, shown only for the operations the cover reports. Stop is the reason a
    /// toggle isn't enough: it's the only way to halt a cover midway.
    @ViewBuilder
    private var buttonsSection: some View {
        // The screen only exists for capable covers, so at least one of these is always present.
        let capabilities = viewModel.capabilities
        Section {
            HStack(spacing: DesignSystem.Spaces.one) {
                if capabilities?.supportsOpen == true {
                    coverButton(symbol: .arrowUp, label: L10n.Watch.CoverControls.open) {
                        viewModel.open()
                    }
                }
                if capabilities?.supportsStop == true {
                    coverButton(symbol: .stopFill, label: L10n.Watch.CoverControls.stop) {
                        viewModel.stop()
                    }
                }
                if capabilities?.supportsClose == true {
                    coverButton(symbol: .arrowDown, label: L10n.Watch.CoverControls.close) {
                        viewModel.close()
                    }
                }
            }
            .listRowBackground(Color.clear)
        }
    }

    private func coverButton(symbol: SFSymbol, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spaces.half) {
                Image(systemSymbol: symbol)
                    .font(.body.weight(.semibold))
                Text(verbatim: label)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
        }
        // Explicit style, like the climate controls: with the automatic one a `List` row holding
        // several buttons becomes a single tap target, so tapping open would also stop the cover.
        .buttonStyle(.bordered)
    }

    private var positionBinding: Binding<Double> {
        Binding(
            get: { viewModel.position },
            set: { viewModel.setPosition($0) }
        )
    }
}

#Preview {
    MaterialDesignIcons.register()
    let item = MagicItem(id: "cover.living_room_blind", serverId: "1", type: .entity)
    let info = MagicItem.Info(
        id: "1-cover.living_room_blind",
        name: "Living room blind",
        iconName: "mdi:blinds"
    )
    let entity = try? HAEntity(
        entityId: "cover.living_room_blind",
        state: "open",
        lastChanged: Date(timeIntervalSinceNow: -600),
        lastUpdated: Date(timeIntervalSinceNow: -60),
        attributes: [
            "friendly_name": "Living room blind",
            "device_class": "blind",
            "supported_features": 15,
            "current_position": 60,
        ],
        context: .init(id: "", userId: "", parentId: "")
    )
    // In the app this screen is pushed by a row inside the home's NavigationStack.
    return NavigationStack {
        WatchCoverControlsView(item: item, itemInfo: info, initialEntity: entity)
    }
}
