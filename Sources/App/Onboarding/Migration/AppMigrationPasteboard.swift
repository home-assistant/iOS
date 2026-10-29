import Foundation
import UIKit

/// The sealed payload rides on the general pasteboard, the one channel two apps from different
/// teams share: only ciphertext ever lands there (the key travels in the request URL), it is local to
/// this device, expires on its own, and the receiver removes it in the same step as reading it.
enum AppMigrationPasteboard {
    static let type = "io.home-assistant.app-migration"
    static let lifetime: TimeInterval = 60

    static func write(_ data: Data) {
        UIPasteboard.general.setItems(
            [[type: data]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(lifetime)]
        )
    }

    /// Reads the payload and removes it from the pasteboard in the same step, so nothing stays behind
    /// whether or not the caller manages to open it.
    static func take() -> Data? {
        let data = UIPasteboard.general.data(forPasteboardType: type)
        clear()
        return data
    }

    static func clear() {
        guard UIPasteboard.general.contains(pasteboardTypes: [type]) else { return }
        UIPasteboard.general.items = []
    }
}
