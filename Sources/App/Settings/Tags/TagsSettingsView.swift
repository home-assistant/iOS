import Shared
import SwiftUI

struct TagsSettingsView: View {
    var body: some View {
        List {
            Section {
                NavigationLink(destination: NFCListView()) {
                    Label {
                        Text(L10n.Nfc.List.title)
                    } icon: {
                        MaterialDesignIconsImage(icon: .nfcVariantIcon, size: 24)
                    }
                }

                NavigationLink(destination: AllowedTagURLsView()) {
                    Label {
                        Text(L10n.Settings.Tags.AllowedUrls.title)
                    } icon: {
                        MaterialDesignIconsImage(icon: .linkVariantIcon, size: 24)
                    }
                }
            }
        }
        .navigationTitle(L10n.Settings.Tags.title)
    }
}
