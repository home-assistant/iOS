import GRDB
import Shared
import SwiftUI

struct AllowedTagURLsView: View {
    @State private var urls: [String] = []

    var body: some View {
        List {
            if urls.isEmpty {
                Section {
                    Text(L10n.Settings.Tags.AllowedUrls.empty)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(footer: Text(L10n.Settings.Tags.AllowedUrls.footer)) {
                    ForEach(urls, id: \.self) { url in
                        Text(url)
                            .textSelection(.enabled)
                            .lineLimit(3)
                    }
                    .onDelete(perform: deleteURLs)
                }
            }
        }
        .navigationTitle(L10n.Settings.Tags.AllowedUrls.title)
        .onAppear(perform: loadURLs)
    }

    private func loadURLs() {
        urls = TrustedURLAllowlistRecord.allowedURLs(database: Current.database())
    }

    private func deleteURLs(at offsets: IndexSet) {
        let values = offsets.map { urls[$0] }

        do {
            for url in values {
                try TrustedURLAllowlistRecord.delete(url: url, database: Current.database())
            }
            urls.remove(atOffsets: offsets)
        } catch {
            Current.Log.error("Failed to delete allowed tag URLs: \(error.localizedDescription)")
        }
    }
}
