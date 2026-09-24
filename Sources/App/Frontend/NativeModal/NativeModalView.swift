import SFSafeSymbols
import Shared
import SwiftUI

/// A native modal: the frontend's page under a standard navigation bar showing what the page's own
/// header would (see `NativeModalHeader`): a title over a breadcrumb, a close or back button, icon
/// buttons and an overflow menu. The native loader covers the page until its frontend reports
/// loaded, so the frontend's own launch screen is never seen.
struct NativeModalView<Content: View>: View {
    @ObservedObject var model: NativeModalModel
    let onClose: () -> Void
    /// A header item was tapped; the id is the frontend's.
    let onAction: (String) -> Void
    let onDisappear: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .ignoresSafeArea()
                .overlay {
                    if model.isLoading {
                        NativeModalLoadingView()
                    }
                }
                .navigationTitle(model.title)
                .modifier(NativeModalSubtitleModifier(subtitle: model.subtitle))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        leadingButton
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        ForEach(model.actions) { action in
                            Button {
                                onAction(action.id)
                            } label: {
                                NativeModalHeaderIcon(name: action.icon)
                            }
                            .accessibilityLabel(action.label)
                        }
                        if !model.menu.isEmpty {
                            menu
                        }
                    }
                }
        }
        .onDisappear(perform: onDisappear)
    }

    @ViewBuilder private var leadingButton: some View {
        switch model.navigation {
        case .close:
            CloseButton {
                onClose()
            }
        case .back:
            Button {
                onAction("back")
            } label: {
                Image(systemSymbol: .chevronBackward)
            }
            .accessibilityLabel(model.navigationLabel)
        }
    }

    private var menu: some View {
        Menu {
            ForEach(model.menu) { item in
                Button {
                    onAction(item.id)
                } label: {
                    Label {
                        Text(item.label)
                    } icon: {
                        NativeModalHeaderIcon(name: item.icon)
                    }
                }
                .disabled(item.isDisabled)
                if item.hasDividerAfter {
                    Divider()
                }
            }
        } label: {
            Image(systemSymbol: .ellipsis)
        }
        .accessibilityLabel(model.menuLabel)
    }
}

#Preview {
    NativeModalView(
        model: NativeModalModel(
            title: "Kitchen ceiling",
            subtitle: "Kitchen ▸ Hue bridge",
            isLoading: false,
            navigationLabel: "Close",
            menuLabel: "Menu",
            actions: [
                .init(id: "history", label: "History", icon: "mdi:chart-box-outline"),
                .init(id: "settings", label: "Settings", icon: "mdi:cog-outline"),
            ],
            menu: [
                .init(id: "device", label: "Device info", icon: "mdi:devices"),
                .init(id: "related", label: "Related", icon: "mdi:link-variant"),
                .init(id: "details", label: "Details", icon: "mdi:information-outline"),
            ]
        ),
        onClose: {},
        onAction: { _ in },
        onDisappear: {}
    ) {
        Color(uiColor: .systemBackground)
    }
}
