import Shared
import SwiftUI
import SFSafeSymbols

struct WatchMagicViewRow: View {
    @StateObject private var viewModel: WatchMagicViewRowViewModel

    init(item: MagicItem, itemInfo: MagicItem.Info) {
        self._viewModel = .init(wrappedValue: .init(item: item, itemInfo: itemInfo))
    }

    var body: some View {
        Button {
            viewModel.executeItem()
        } label: {
            HStack(spacing: DesignSystem.Spaces.one) {
                iconToDisplay
                    .animation(.bouncy, value: viewModel.state)
                Text(viewModel.item.name(info: viewModel.itemInfo))
                    .font(.body.bold())
                    .foregroundStyle(textColor)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .padding(.trailing)
            }
            .frame(maxWidth: .infinity)
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
        .listRowBackground(Color.clear)
        .modify({ view in
            if #available(watchOS 26.0, *) {
                if let backgroundForWatchItem {
                    view
                        .buttonStyle(.glassProminent)
                        .tint(backgroundForWatchItem)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                } else {
                    view.buttonStyle(.glass)
                }
            } else {
                view
                    .listRowBackground((backgroundForWatchItem ?? Color.gray.opacity(0.3)).cornerRadius(14))
            }
        })
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
    }

    private var iconToDisplay: some View {
        VStack {
            switch viewModel.state {
            case .idle:
                Image(uiImage: viewModel.item.icon(info: viewModel.itemInfo).image(
                    ofSize: .init(width: 24, height: 24),
                    color: .init(hex: viewModel.itemInfo.customization?.iconColor)
                ))
                .foregroundStyle(Color(uiColor: .init(hex: viewModel.itemInfo.customization?.iconColor)))
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
        .frame(width: 38, height: 38)
        .modify({ view in
            if #available(watchOS 26.0, *) {
                view
                    .glassEffect(.clear.tint(Color(uiColor: .init(hex: viewModel.itemInfo.customization?.iconColor)).opacity(0.3)), in: .circle)
            } else {
                view
                    .background(Color(uiColor: .init(hex: viewModel.itemInfo.customization?.iconColor)).opacity(0.3))
                    .clipShape(Circle())
            }
        })
        .padding([.vertical, .trailing], DesignSystem.Spaces.half)
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
            item: .init(id: "1", serverId: "1", type: .action),
            itemInfo: .init(id: "1", name: "New Action", iconName: "earth")
        )
    }
    .background(Color.red)
}
