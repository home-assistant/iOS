import SFSafeSymbols
import Shared
import SwiftUI

struct WatchMagicViewRow: View {
    @StateObject private var viewModel: WatchMagicViewRowViewModel
    private let subtitle: String?
    private let layout: WatchLayout

    init(item: MagicItem, itemInfo: MagicItem.Info, subtitle: String? = nil, layout: WatchLayout = .list) {
        self._viewModel = .init(wrappedValue: .init(item: item, itemInfo: itemInfo))
        self.subtitle = subtitle
        self.layout = layout
    }

    var body: some View {
        Button {
            viewModel.executeItem()
        } label: {
            label
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

    private var iconColor: UIColor {
        if let hex = viewModel.itemInfo.customization?.iconColor {
            .init(hex: hex)
        } else {
            .white
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
                subtitle: subtitle,
                textColor: textColor,
                icon: { iconToDisplay.animation(.bouncy, value: viewModel.state) }
            )
        }
    }

    private var iconToDisplay: some View {
        VStack {
            stateIcon(size: 24)
                .padding()
        }
        .watchRowIconContainer(color: iconColor)
    }

    private var gridIcon: some View {
        stateIcon(size: 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .accessibilityLabel(Text(viewModel.item.name(info: viewModel.itemInfo)))
    }

    @ViewBuilder
    private func stateIcon(size: CGFloat) -> some View {
        switch viewModel.state {
        case .idle:
            Image(uiImage: viewModel.item.icon(info: viewModel.itemInfo).image(
                ofSize: .init(width: size, height: size),
                color: iconColor
            ))
            .foregroundStyle(Color(uiColor: iconColor))
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
    }
    .background(Color.red)
}
