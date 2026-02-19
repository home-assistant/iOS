import SFSafeSymbols
import Shared
import SwiftUI

struct WatchFolderRow: View {
    let item: MagicItem
    let itemInfo: MagicItem.Info
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: DesignSystem.Spaces.one) {
                iconView
                Text(item.name(info: itemInfo))
                    .font(.body.bold())
                    .foregroundStyle(textColor)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                Image(systemSymbol: .chevronRight)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, DesignSystem.Spaces.half)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .modify { view in
            if #available(watchOS 26.0, *) {
                if let backgroundForWatchItem {
                    view
                        .listRowBackground(Color.clear)
                        .buttonStyle(.glassProminent)
                        .tint(backgroundForWatchItem)
                } else {
                    view
                        .listRowBackground(Color.clear)
                        .buttonStyle(.glass)
                }
            } else {
                view
                    .listRowBackground((backgroundForWatchItem ?? Color.gray.opacity(0.3)).cornerRadius(14))
            }
        }
    }

    private var iconView: some View {
        VStack {
            Image(uiImage: item.icon(info: itemInfo).image(
                ofSize: .init(width: 24, height: 24),
                color: .init(hex: itemInfo.customization?.iconColor)
            ))
            .foregroundStyle(Color(uiColor: .init(hex: itemInfo.customization?.iconColor)))
            .padding()
        }
        .frame(width: 38, height: 38)
        .modify { view in
            if #available(watchOS 26.0, *) {
                view
                    .glassEffect(
                        .clear
                            .tint(Color(uiColor: .init(hex: itemInfo.customization?.iconColor)).opacity(0.3)),
                        in: .circle
                    )
            } else {
                view
                    .background(Color(uiColor: .init(hex: itemInfo.customization?.iconColor)).opacity(0.3))
                    .clipShape(Circle())
            }
        }
        .padding([.vertical, .trailing], DesignSystem.Spaces.half)
    }

    private var textColor: Color {
        if let textColor = itemInfo.customization?.textColor {
            .init(uiColor: .init(hex: textColor))
        } else {
            .white
        }
    }

    private var backgroundForWatchItem: Color? {
        if let backgroundColor = itemInfo.customization?.backgroundColor {
            Color(uiColor: .init(hex: backgroundColor))
        } else {
            nil
        }
    }
}

#Preview {
    MaterialDesignIcons.register()
    return List {
        WatchFolderRow(
            item: .init(
                id: "folder1",
                serverId: "",
                type: .folder,
                customization: .init(iconColor: "#03A9F4"),
                displayText: "Living Room"
            ),
            itemInfo: .init(
                id: "folder1",
                name: "Living Room",
                iconName: "mdi:folder",
                customization: .init(iconColor: "#03A9F4")
            )
        ) {
            print("Folder tapped")
        }
    }
}
