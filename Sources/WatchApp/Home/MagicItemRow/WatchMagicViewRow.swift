import SFSafeSymbols
import Shared
import SwiftUI

struct WatchMagicViewRow: View {
    @StateObject private var viewModel: WatchMagicViewRowViewModel
    @Environment(\.watchNavigate) private var navigate
    private let subtitle: String?
    private let layout: WatchLayout

    init(item: MagicItem, itemInfo: MagicItem.Info, subtitle: String? = nil, layout: WatchLayout = .list) {
        self._viewModel = .init(wrappedValue: .init(item: item, itemInfo: itemInfo))
        self.subtitle = subtitle
        self.layout = layout
    }

    var body: some View {
        // The confirmation dialog and alerts hang off this per-row container (not a shared parent
        // list): which button triggers them depends on the row variant below.
        Group {
            if layout == .list, let controlsDestination = viewModel.controlsDestination {
                // Two sibling tap targets — the icon toggles, the body opens the controls
                // screen. Not wrapped in a row `Button`: SwiftUI doesn't support nested buttons.
                splitControlsLabel(destination: controlsDestination)
            } else {
                Button {
                    viewModel.executeItem()
                } label: {
                    label
                }
            }
        }
        .confirmationDialog(
            L10n.Watch.Home.Run.Confirmation.title(viewModel.item.name(info: viewModel.itemInfo)),
            isPresented: $viewModel.showConfirmationDialog,
            actions: {
                Button(action: {
                    viewModel.confirmationAction()
                }, label: {
                    Text(verbatim: L10n.yesLabel)
                })
                Button(action: {}, label: {
                    Text(verbatim: L10n.cancelLabel)
                })
                .tint(.red)
            }
        )
        .alert(
            Text(verbatim: L10n.Watch.Home.Unsupported.title),
            isPresented: $viewModel.showUnsupportedAlert
        ) {
            Button(role: .cancel) {} label: { Text(verbatim: L10n.okLabel) }
        } message: {
            Text(verbatim: L10n.Watch.Home.Unsupported.message(viewModel.domainName))
        }
        .onAppear {
            viewModel.startStateUpdates()
        }
        .onDisappear {
            viewModel.stopStateUpdates()
        }
        .modify { view in
            if layout == .grid {
                view.watchHomeItemGridStyle(tint: backgroundForWatchItem)
            } else {
                view
                    .frame(maxWidth: .infinity)
                    .watchHomeItemRowStyle(tint: backgroundForWatchItem)
            }
        }
        .onChange(of: viewModel.state) { newValue in
            // TODO: On watchOS 10 this can be replaced by '.sensoryFeedback' modifier
            let currentDevice = WKInterfaceDevice.current()
            switch newValue {
            case .success:
                currentDevice.play(.success)
            case .failure:
                currentDevice.play(.failure)
            case .loading:
                currentDevice.play(.click)
            default:
                break
            }
        }
        // Full screen (not an alert) so the failure reason — and what to do about it — stays
        // readable on the small display.
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            MagicItemExecutionErrorView(
                itemName: viewModel.item.name(info: viewModel.itemInfo),
                message: viewModel.errorMessage ?? "",
                onDismiss: { viewModel.errorMessage = nil }
            )
        }
        // Sensors run nothing when tapped: they open their own read-only details screen instead.
        // (A capable light's controls screen is not a sheet — its row body pushes it.)
        .sheet(isPresented: $viewModel.showDetails) {
            WatchEntityDetailsView(viewModel: .init(item: viewModel.item, itemInfo: viewModel.itemInfo))
        }
        // Developer "Verbose item execution": a live log of the run, dismissed explicitly so the
        // steps stay readable after the execution finishes.
        .fullScreenCover(isPresented: $viewModel.showTrace) {
            if let trace = viewModel.trace {
                MagicItemExecutionTraceView(
                    trace: trace,
                    itemName: viewModel.item.name(info: viewModel.itemInfo)
                ) {
                    viewModel.showTrace = false
                }
            }
        }
    }

    @ViewBuilder
    private var label: some View {
        if layout == .grid {
            gridIcon
                .animation(.bouncy, value: viewModel.state)
        } else {
            WatchHomeItemLabel(
                name: viewModel.item.name(info: viewModel.itemInfo),
                subtitle: subtitleToDisplay,
                textColor: textColor,
                icon: { iconToDisplay.animation(.bouncy, value: viewModel.state) }
            )
        }
    }

    /// A capable entity (light, cover, fan) splits the row in two sibling tap targets: the icon
    /// keeps toggling while the row body pushes its controls screen — the chevron promises a
    /// push, so it must not be presented modally. The pushed screen resolves in `WatchHomeView`'s
    /// destination registration.
    private func splitControlsLabel(destination: WatchHomeNavigation) -> some View {
        WatchHomeItemLabel(
            name: viewModel.item.name(info: viewModel.itemInfo),
            subtitle: subtitleToDisplay,
            textColor: textColor,
            icon: { iconToDisplay.animation(.bouncy, value: viewModel.state) },
            accessory: {
                // Same chevron as folder rows: the row body navigates somewhere.
                Image(systemSymbol: .chevronRight)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            },
            onIconTap: { viewModel.executeItem() },
            onBodyTap: { navigate(destination) }
        )
    }

    private var subtitleToDisplay: String? {
        let combined = [viewModel.stateText, subtitle].compactMap { $0 }.joined(separator: " • ")
        return combined.isEmpty ? nil : combined
    }

    private var iconToDisplay: some View {
        VStack {
            stateIcon(size: 24)
                .padding()
        }
        .watchRowIconContainer(color: viewModel.iconColor)
        .overlay(alignment: .bottomTrailing) {
            staleStateBadge
        }
    }

    private var gridIcon: some View {
        VStack(spacing: DesignSystem.Spaces.half) {
            stateIcon(size: 28)
            // A grid tile shows only an icon, which says nothing about a sensor — so display-only
            // items get their value under it, the whole point of putting them on the watch.
            if viewModel.isDisplayOnly, let stateText = viewModel.stateText {
                Text(verbatim: stateText)
                    .font(.caption2)
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, DesignSystem.Spaces.half)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .accessibilityLabel(Text(viewModel.item.name(info: viewModel.itemInfo)))
        .overlay(alignment: .bottomTrailing) {
            staleStateBadge
        }
    }

    /// Warns that the displayed state may be outdated (no successful refresh recently).
    @ViewBuilder
    private var staleStateBadge: some View {
        if viewModel.isStateStale {
            Image(systemSymbol: .exclamationmarkCircleFill)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.black, .orange)
                .font(.system(size: 12))
        }
    }

    @ViewBuilder
    private func stateIcon(size: CGFloat) -> some View {
        switch viewModel.state {
        case .idle:
            Image(uiImage: viewModel.icon.image(
                ofSize: .init(width: size, height: size),
                color: viewModel.iconColor
            ))
            .foregroundStyle(Color(uiColor: viewModel.iconColor))
        case .loading:
            ProgressView()
                .progressViewStyle(.circular)
                .frame(width: size, height: size)
                .shadow(color: .white, radius: 10)
        case .success:
            Image(systemSymbol: .checkmarkCircleFill)
                .font(.system(size: size))
                .foregroundStyle(.white)
        case .failure:
            Image(systemSymbol: .xmarkCircle)
                .font(.system(size: size))
                .foregroundStyle(.white)
        }
    }

    private var textColor: Color {
        if let textColor = viewModel.itemInfo.customization?.textColor {
            .init(uiColor: .init(hex: textColor))
        } else {
            .white
        }
    }

    private var backgroundForWatchItem: Color? {
        if let backgroundColor = viewModel.itemInfo.customization?.backgroundColor {
            Color(uiColor: .init(hex: backgroundColor))
        } else {
            nil
        }
    }
}

#Preview {
    MaterialDesignIcons.register()
    return List {
        WatchMagicViewRow(
            item: .init(id: "1", serverId: "1", type: .script),
            itemInfo: .init(
                id: "1",
                name: "New script",
                iconName: "mdi:door-closed-lock",
                customization: .init(backgroundColor: "#ff00ff")
            )
        )
        WatchMagicViewRow(
            item: .init(id: "scene.one", serverId: "1", type: .scene),
            itemInfo: .init(id: "1", name: "New scene", iconName: "earth")
        )
        WatchMagicViewRow(
            item: .init(id: "sensor.living_room_temperature", serverId: "1", type: .entity),
            itemInfo: .init(id: "1", name: "Living room temperature", iconName: "mdi:thermometer")
        )
        WatchMagicViewRow(
            item: .init(id: "light.kitchen", serverId: "1", type: .entity),
            itemInfo: .init(id: "1", name: "Kitchen light", iconName: "mdi:lightbulb")
        )
    }
    .background(Color.red)
}
