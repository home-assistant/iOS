@testable import HomeAssistant
import Testing
import UIKit

struct AppAlertTests {
    @MainActor @Test func alertControllerCarriesTheTitleMessageAndActions() {
        var confirmed = false
        let alert = AppAlert(
            title: "Delete?",
            message: "This cannot be undone.",
            actions: [
                .init(title: "Delete", style: .destructive) { confirmed = true },
                .init(title: "Cancel", style: .cancel),
                .init(title: "Later"),
            ]
        )

        let controller = alert.makeAlertController()

        #expect(controller.title == "Delete?")
        #expect(controller.message == "This cannot be undone.")
        #expect(controller.preferredStyle == .alert)
        #expect(controller.actions.map(\.title) == ["Delete", "Cancel", "Later"])
        #expect(controller.actions.map(\.style) == [.destructive, .cancel, .default])
        #expect(confirmed == false)
    }

    @MainActor @Test func alertWithoutTextHasNoTitleOrMessage() {
        let controller = AppAlert(actions: [.init(title: "OK")]).makeAlertController()

        #expect(controller.title == nil)
        #expect(controller.message == nil)
        #expect(controller.actions.count == 1)
    }
}
