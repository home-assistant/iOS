import SFSafeSymbols
import Shared
import SwiftUI

/// Menu listing the item types that can be added to CarPlay Quick Access. `showAddFolder` is
/// disabled inside a folder, since CarPlay folders can't contain other folders.
struct CarPlayAddItemMenu: View {
    let showAddFolder: Bool
    let onSelectDestination: (CarPlayAddItemDestination) -> Void
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
                onSelectDestination(.assist)
            } label: {
                Label {
                    Text(
                        isAssistSupported ?
                            L10n.Widgets.Action.Name.assist :
                            L10n.MagicItem.Action.Assist.Unsupported.title
                    )
                } icon: {
                    Image(uiImage: MaterialDesignIcons.microphoneIcon.image(
                        ofSize: .init(width: 18, height: 18),
                        color: .label
                    ))
                }
            }
            .disabled(!isAssistSupported)

            Button {
                onSelectDestination(.assistPrompt)
            } label: {
                Label {
                    Text(
                        isAssistSupported ?
                            L10n.MagicItem.ItemType.AssistPrompt.title :
                            L10n.MagicItem.ItemType.AssistPrompt.Unsupported.title
                    )
                } icon: {
                    Image(uiImage: MaterialDesignIcons.messageProcessingOutlineIcon.image(
                        ofSize: .init(width: 18, height: 18),
                        color: .label
                    ))
                }
            }
            .disabled(!isAssistSupported)

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

    private var isAssistSupported: Bool {
        if #available(iOS 26.4, *) {
            return true
        } else {
            return false
        }
    }
}

#Preview {
    List {
        CarPlayAddItemMenu(
            showAddFolder: true,
            onSelectDestination: { _ in },
            onAddFolder: {}
        )
    }
}
