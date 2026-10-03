import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The number on the app's icon: the label on the Dock tile on the Mac, the application icon badge elsewhere.
struct AppIconBadge {
    var count: () -> Int
    var clear: () -> Void

    @MainActor
    static let application = AppIconBadge(
        count: {
            #if os(macOS)
            NSApp.dockTile.badgeLabel.flatMap { Int($0) } ?? 0
            #else
            UIApplication.shared.applicationIconBadgeNumber
            #endif
        },
        clear: {
            #if os(macOS)
            NSApp.dockTile.badgeLabel = nil
            #else
            UIApplication.shared.applicationIconBadgeNumber = 0
            #endif
        }
    )
}
