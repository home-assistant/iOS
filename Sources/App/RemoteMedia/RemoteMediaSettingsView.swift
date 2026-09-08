#if !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

/// Shows which media player the phone is currently following and lets the user stop.
///
/// Choosing a player happens where the user already is — the entity's more info dialog, under
/// "Add to" — so this screen deliberately has no picker of its own.
@available(iOS 27.0, *)
struct RemoteMediaSettingsView: View {
    @ObservedObject var coordinator: RemoteMediaCoordinator

    init(coordinator: RemoteMediaCoordinator? = nil) { self.coordinator = coordinator ?? .shared }

    var body: some View {
        if let selection = coordinator.selection {
            List {
                // The header carries the title, so this screen must not also set a navigation
                // title: the two would stack as the list scrolls.
                AppleLikeListTopRowHeader(
                    image: .speakerIcon,
                    title: L10n.RemoteMedia.title,
                    subtitle: L10n.RemoteMedia.description
                )
                Section {
                    LabeledContent(L10n.RemoteMedia.following) {
                        Text(coordinator.snapshot?.deviceName ?? selection.entityId)
                    }
                    // Which server it came from only says something when there is more than one,
                    // the same rule the entity picker uses for its own server filter.
                    if Current.servers.all.count > 1 {
                        LabeledContent(L10n.Settings.ServerSelect.title) {
                            Text(
                                Current.servers.server(forServerIdentifier: selection.serverId)?.info.name
                                    ?? selection.serverId
                            )
                        }
                    }
                    if coordinator.snapshot?.hasMeaningfulMedia != true {
                        Text(L10n.RemoteMedia.waiting)
                            .foregroundStyle(.secondary)
                    }
                    Button(L10n.RemoteMedia.stopFollowing, role: .destructive) {
                        coordinator.follow(nil)
                    }
                }
                if let error = coordinator.error {
                    Section {
                        Text(error).foregroundStyle(.red)
                        Button(L10n.RemoteMedia.retry) { coordinator.refresh() }
                    }
                }
            }
        } else {
            // No list, so no header to carry the title, and the screen still needs one.
            HAEmptyStateView(
                icon: .speakerOffIcon,
                heading: L10n.RemoteMedia.Empty.title,
                description: L10n.RemoteMedia.Empty.instructions
            )
            .navigationTitle(L10n.RemoteMedia.title)
        }
    }
}

@available(iOS 27.0, *)
extension RemoteMediaSettingsView: SettingsScreenSearchable {
    static var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(L10n.RemoteMedia.following),
            SettingsSearchEntry(L10n.RemoteMedia.stopFollowing),
        ]
    }
}

@available(iOS 27.0, *)
#Preview {
    NavigationStack { RemoteMediaSettingsView() }
}
#endif
