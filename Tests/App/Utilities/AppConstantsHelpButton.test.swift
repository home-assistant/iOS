@testable import Shared
import Testing
import UIKit

/// The help bar button draws a Material Design icon, so it needs the font bundle the app ships.
@MainActor
struct AppConstantsHelpButtonTests {
    @Test func helpButtonIsLabelled() {
        let item = AppConstants.helpBarButtonItem
        #expect(item.accessibilityLabel == L10n.helpLabel)
        #expect(item.image != nil)
    }
}
