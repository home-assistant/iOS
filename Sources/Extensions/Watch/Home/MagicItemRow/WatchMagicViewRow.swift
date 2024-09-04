import Shared
import SwiftUI

struct WatchMagicViewRow: View {
    @StateObject private var viewModel: WatchMagicViewRowViewModel

    init(item: MagicItem, itemInfo: MagicItem.Info) {
        self._viewModel = .init(wrappedValue: .init(item: item, itemInfo: itemInfo))
    }

    var body: some View {
        Button {
            viewModel.executeItem()
        } label: {
            HStack(spacing: Spaces.one) {
                iconToDisplay
                    .animation(.bouncy, value: viewModel.state)
                Text(viewModel.itemInfo.name)
                    .font(.footnote.bold())
                    .foregroundStyle(textColor)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing)
            }
        }
        .listRowBackground(backgroundForWatchItem.cornerRadius(14))
        .confirmationDialog(
            L10n.Watch.Home.Run.Confirmation.title(viewModel.itemInfo.name),
            isPresented: $viewModel.showConfirmationDialog,
            actions: {
                Button(action: {
                    viewModel.confirmationAction()
                }, label: {
                    Text(L10n.yesLabel)
                })
                Button(action: {}, label: {
                    Text(L10n.cancelLabel)
                })
                .tint(.red)
            }
        )
        .modify { view in
            if let backgroundColor = viewModel.item.customization?.backgroundColor {
                view.listRowBackground(
                    Color(uiColor: .init(hex: backgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                )
            } else {
                view
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
    }

    private var iconToDisplay: some View {
        VStack {
            switch viewModel.state {
            case .idle:
                Image(uiImage: image)
                    .foregroundStyle(Color(uiColor: .init(hex: viewModel.itemInfo.customization?.iconColor)))
                    .padding()
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(width: 24, height: 24)
                    .shadow(color: .white, radius: 10)
                    .padding()
            case .success:
                makeStateImage(systemName: "checkmark.circle.fill")
            case .failure:
                makeStateImage(systemName: "xmark.circle")
            }
        }
        .frame(width: 38, height: 38)
        .background(Color(uiColor: .init(hex: viewModel.itemInfo.customization?.iconColor)).opacity(0.3))
        .clipShape(Circle())
        .padding([.vertical, .trailing], Spaces.half)
    }

    private func makeStateImage(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 24))
            .foregroundStyle(.white)
            .padding()
    }

    private var textColor: Color {
        if let textColor = viewModel.item.customization?.textColor {
            .init(uiColor: .init(hex: textColor))
        } else {
            .white
        }
    }

    private var backgroundForWatchItem: Color {
        if let backgroundColor = viewModel.itemInfo.customization?.backgroundColor {
            Color(uiColor: .init(hex: backgroundColor))
        } else {
            .gray.opacity(0.3)
        }
    }

    private var image: UIImage {
        var icon: MaterialDesignIcons
        switch viewModel.item.type {
        case .action, .scene:
            icon = MaterialDesignIcons(named: viewModel.itemInfo.iconName, fallback: .scriptTextOutlineIcon)
        case .script:
            icon = MaterialDesignIcons(
                serversideValueNamed: viewModel.itemInfo.iconName,
                fallback: .scriptTextOutlineIcon
            )
        }

        return icon.image(
            ofSize: .init(width: 24, height: 24),
            color: .init(hex: viewModel.itemInfo.customization?.iconColor)
        )
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
