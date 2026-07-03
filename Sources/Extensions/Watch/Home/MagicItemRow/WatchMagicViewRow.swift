import SFSafeSymbols
import Shared
import SwiftUI

struct WatchMagicViewRow: View {
    @StateObject private var viewModel: WatchMagicViewRowViewModel
    private let subtitle: String?

    init(item: MagicItem, itemInfo: MagicItem.Info, subtitle: String? = nil) {
        self._viewModel = .init(wrappedValue: .init(item: item, itemInfo: itemInfo))
        self.subtitle = subtitle
    }

    var body: some View {
        Button {
            viewModel.executeItem()
        } label: {
            WatchHomeItemLabel(
                name: viewModel.item.name(info: viewModel.itemInfo),
                subtitle: subtitle,
                textColor: textColor,
                icon: { iconToDisplay.animation(.bouncy, value: viewModel.state) }
            )
        }
        .frame(maxWidth: .infinity)
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
        .watchHomeItemRowStyle(tint: backgroundForWatchItem)
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
        .alert(
            Text(verbatim: L10n.Watch.Home.Run.Error.title),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button(L10n.okLabel, role: .cancel) {}
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(verbatim: errorMessage)
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

    private var iconToDisplay: some View {
        VStack {
            switch viewModel.state {
            case .idle:
                Image(uiImage: viewModel.item.icon(info: viewModel.itemInfo).image(
                    ofSize: .init(width: 24, height: 24),
                    color: iconColor
                ))
                .foregroundStyle(Color(uiColor: iconColor))
                .padding()
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(width: 24, height: 24)
                    .shadow(color: .white, radius: 10)
                    .padding()
            case .success:
                makeStateImage(systemName: .checkmarkCircleFill)
            case .failure:
                makeStateImage(systemName: .xmarkCircle)
            }
        }
        .watchRowIconContainer(color: iconColor)
    }

    private func makeStateImage(systemName: SFSymbol) -> some View {
        Image(systemSymbol: systemName)
            .font(.system(size: 24))
            .foregroundStyle(.white)
            .padding()
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
