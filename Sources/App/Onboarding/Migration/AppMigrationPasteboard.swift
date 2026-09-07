import Foundation
import UIKit

/// The sealed payload rides on the general pasteboard: local to this device, expiring on its own,
/// and removed by the receiver as soon as it has been read.
enum AppMigrationPasteboard {
    static let type = "io.home-assistant.app-migration"
    static let lifetime: TimeInterval = 5 * 60

    static func write(_ data: Data) {
        UIPasteboard.general.setItems(
            [[type: data]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(lifetime)]
        )
    }

    static func read() -> Data? {
        UIPasteboard.general.data(forPasteboardType: type)
    }

    static func clear() {
        guard UIPasteboard.general.contains(pasteboardTypes: [type]) else { return }
        UIPasteboard.general.items = []
    }
}
