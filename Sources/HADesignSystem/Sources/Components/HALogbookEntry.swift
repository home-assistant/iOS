#if !os(watchOS)
import Foundation
import HAIconic
import SwiftUI

/// One line of an ``HALogbookCard``: something that happened, when, and to what.
///
/// Frontend counterpart: the `LogbookRenderItem` that `ha-logbook-entry` draws, rather than an
/// element of its own.
///
/// The message is already assembled, because turning a state change into "was turned on by Bruno"
/// needs the entity registry and the user list — the app's job, not the package's.
public struct HALogbookEntry: Identifiable, Sendable {
    public let id: String
    public let when: Date
    public let name: String
    public let message: String
    public let icon: MaterialDesignIcons?
    public let color: Color

    public init(
        id: String,
        when: Date,
        name: String,
        message: String,
        icon: MaterialDesignIcons? = nil,
        color: Color = .haPrimary
    ) {
        self.id = id
        self.when = when
        self.name = name
        self.message = message
        self.icon = icon
        self.color = color
    }
}

extension HALogbookEntry: FrontendComponent {
    public static var frontendComponentName: String { "ha-logbook-entry" }
}

#endif
