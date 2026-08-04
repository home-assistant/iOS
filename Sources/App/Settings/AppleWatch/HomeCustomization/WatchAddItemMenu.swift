import SFSafeSymbols
import Shared
import SwiftUI

/// Menu listing what can be added to the Apple Watch home configuration. `showAddFolder` is
/// disabled inside a folder, since watch folders can't contain other folders.
struct WatchAddItemMenu: View {
    let showAddFolder: Bool
    let onSelectDestination: (WatchAddItemDestination) -> Void
    let onAddFolder: () -> Void

    /// Resolved when the menu is built rather than on appear, so the Complication entry is there the
    /// first time the menu opens instead of appearing under the user's finger.
    private let hasComplications = ((try? WatchComplicationConfig.watchListAddable()) ?? []).isEmpty == false

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

            Button {
                onSelectDestination(.assist)
            } label: {
                Label {
                    Text(L10n.Widgets.Action.Name.assist)
                } icon: {
                    Image(uiImage: MaterialDesignIcons.microphoneIcon.image(
                        ofSize: .init(width: 18, height: 18),
                        color: .label
                    ))
                }
            }

            Button {
                onSelectDestination(.assistPrompt)
            } label: {
                Label {
                    Text(L10n.MagicItem.ItemType.AssistPrompt.title)
                } icon: {
                    Image(uiImage: MaterialDesignIcons.messageProcessingOutlineIcon.image(
                        ofSize: .init(width: 18, height: 18),
                        color: .label
                    ))
                }
            }

            // Only offered once a rectangular complication exists — this screen adds an existing one,
            // it never creates one, so with none configured the entry would lead to an empty list.
            if hasComplications {
                Button {
                    onSelectDestination(.complication)
                } label: {
                    Label {
                        Text(L10n.MagicItem.ItemType.Complication.List.title)
                    } icon: {
                        Image(systemSymbol: .applewatch)
                    }
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
