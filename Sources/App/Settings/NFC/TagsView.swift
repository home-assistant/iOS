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
