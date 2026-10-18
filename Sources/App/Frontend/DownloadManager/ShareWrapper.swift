import Foundation

/// What a share sheet offers. A fresh `id` per value is what makes `View.shareSheet(item:)` present
/// again when the same content is shared twice in a row.
struct ShareWrapper: Identifiable {
    let id = UUID()
    let items: [Any]

    init(items: [Any]) {
        self.items = items
    }

    init(url: URL) {
        self.init(items: [url])
    }
}
