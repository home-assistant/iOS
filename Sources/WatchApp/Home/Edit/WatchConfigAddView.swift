import SFSafeSymbols
import Shared
import SwiftUI

/// Add flow for the watch configuration, presented as a navigation drill-down:
/// chooser (Entity / Area / Folder) → server (skipped when only one) → entity or area list →
/// name/icon editor. Everything is resolved from the locally-mirrored database, so the flow works
/// without the phone nearby. Committing performs the mutation, persists, and dismisses the whole
/// sheet via `finish`.
struct WatchConfigAddView: View {
    /// Held without `@ObservedObject` on purpose: the add flow only *calls* the view model (fetch and
    /// mutate) and renders none of its published state, so observing it would rebuild this whole
    /// navigation stack on every unrelated publish — a background sync alone republishes its progress
    /// and status for every chunk it receives.
    let viewModel: WatchHomeViewModel
    /// When set, added items go into this folder instead of the root. Folder creation is only offered
    /// at the root (folders don't nest on the watch).
    let folderId: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            content
                .navigationTitle(Text(verbatim: L10n.Watch.Config.Add.title))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemSymbol: .xmark)
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        chooser
    }

    private var chooser: some View {
        List {
            NavigationLink {
                WatchConfigAddEntitySourceView(
                    viewModel: viewModel,
                    folderId: folderId,
                    finish: { dismiss() }
                )
            } label: {
                chooserRow(icon: Domain.automation.icon(), title: L10n.Watch.Config.Add.entity)
            }

            NavigationLink {
                WatchConfigAddAreaSourceView(
                    viewModel: viewModel,
                    folderId: folderId,
                    finish: { dismiss() }
                )
            } label: {
                chooserRow(icon: .textureBoxIcon, title: L10n.Watch.Config.Add.area)
            }

            // Folders don't nest, so creating one is only offered at the root.
            if folderId == nil {
                NavigationLink {
                    WatchConfigItemEditView(
                        mode: .add,
                        placeholderName: L10n.Watch.Config.Edit.namePlaceholder,
                        item: MagicItem(
                            id: UUID().uuidString,
                            serverId: "",
                            type: .folder,
                            displayText: "",
                            items: []
                        ),
                        info: nil
                    ) { edited in
                        viewModel.addFolder(named: edited.displayText ?? "", iconName: edited.customization?.icon)
                        viewModel.saveConfig()
                        dismiss()
                    }
                } label: {
                    chooserRow(icon: .folderIcon, title: L10n.Watch.Config.Add.folder)
                }
            }
        }
    }

    private func chooserRow(icon: MaterialDesignIcons, title: String) -> some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            Image(uiImage: icon.image(ofSize: .init(width: 24, height: 24), color: .white))
                .frame(width: 38, height: 38)
                .modify { view in
                    if #available(watchOS 26.0, *) {
                        view.glassEffect(.clear.tint(Color.white.opacity(0.3)), in: .circle)
                    } else {
                        view
                            .background(Color.white.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                .padding([.vertical, .trailing], DesignSystem.Spaces.half)
            Text(verbatim: title)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    MaterialDesignIcons.register()
    return WatchConfigAddView(viewModel: WatchHomeViewModel(), folderId: nil)
}
