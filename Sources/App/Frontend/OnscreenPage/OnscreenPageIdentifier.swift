import AppIntents
import Foundation
import Shared

/// Turns the page on screen into the `EntityIdentifier` the system attaches to it, which is what lets
/// Siri resolve a reference to "this page" into the same `PageAppEntity` the widgets already use.
@available(iOS 18.0, *)
enum OnscreenPageIdentifier {
    static func make(for page: OnscreenPage) -> EntityIdentifier? {
        // Hiding a server from Siri hides its screens too. Saying which page someone is looking at is
        // a stronger disclosure than listing the pages they could open, which is what that setting was
        // written for, so it has to respect the same opt-out.
        guard SiriServerExposure.isExposed(serverId: page.serverId) else { return nil }
        return EntityIdentifier(
            for: PageAppEntity.self,
            identifier: PageAppEntity.makeId(serverId: page.serverId, panelPath: page.panelPath)
        )
    }
}
