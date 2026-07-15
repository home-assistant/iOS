import Shared
import SwiftUI

struct TagsView: View {
    var body: some View {
        List {
            NavigationLink {
                NFCListView()
            } label: {
                Text(L10n.Nfc.List.title)
            }

            NavigationLink {
                AllowedTagsView()
            } label: {
                Text(L10n.Tags.Allowed.title)
            }
        }
        .navigationTitle(L10n.Tags.title)
    }
}

extension TagsView: SettingsScreenSearchable {
    static var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(L10n.Nfc.List.title),
            SettingsSearchEntry(L10n.Tags.Allowed.title),
        ]
    }
}
