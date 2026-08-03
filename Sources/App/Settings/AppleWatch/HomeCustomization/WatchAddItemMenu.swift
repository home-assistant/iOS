import SFSafeSymbols
import Shared
import SwiftUI

/// Menu listing what can be added to the Apple Watch home configuration. `showAddFolder` is
/// disabled inside a folder, since watch folders can't contain other folders.
struct WatchAddItemMenu: View {
    let showAddFolder: Bool
    let onSelectDestination: (WatchAddItemDestination) -> Void
    let onAddFolder: () -> Void

    var body: some View {
        Menu {
            Button {
                onSelectDestination(.entity)
            } label: {
                Label {
                    Text(L10n.MagicItem.ItemType.Entity.List.title)
                } icon: {
                    Image(systemSymbol: .lightbulb)
                }
            }

            Button {
                onSelectDestination(.area)
            } label: {
                Label {
                    Text(L10n.MagicItem.ItemType.Area.List.title)
                } icon: {
                    Image(uiImage: MaterialDesignIcons.textureBoxIcon.image(
                        ofSize: .init(width: 18, height: 18),
                        color: .label
                    ))
                }
            }

            if showAddFolder {
                Button {
                    onAddFolder()
                } label: {
                    Label(L10n.Watch.Configuration.AddFolder.title, systemSymbol: .folder)
                }
            }
        } label: {
            Label(L10n.Watch.Configuration.AddItem.title, systemSymbol: .plus)
        }
    }
}

#Preview {
    List {
        WatchAddItemMenu(
            showAddFolder: true,
            onSelectDestination: { _ in },
            onAddFolder: {}
        )
    }
}
