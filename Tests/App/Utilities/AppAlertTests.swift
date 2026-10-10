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

    @Test func returnPressesThePreferredActionOnTheMac() {
        let alert = AppAlert(title: "Open?", actions: [
            .init(title: "Cancel", style: .cancel),
            .init(title: "Always Open"),
            .init(title: "Open", isPreferred: true),
        ])

        #expect(alert.macButtonOrder.map(\.title) == ["Open", "Cancel", "Always Open"])
    }

    @Test func returnPressesCancelRatherThanADestructiveOrUnmarkedAction() {
        let destructiveFirst = AppAlert(actions: [
            .init(title: "Delete", style: .destructive),
            .init(title: "Cancel", style: .cancel),
        ])
        #expect(destructiveFirst.macButtonOrder.map(\.title) == ["Cancel", "Delete"])

        let noCancel = AppAlert(actions: [
            .init(title: "Delete", style: .destructive),
            .init(title: "Keep"),
        ])
        #expect(noCancel.macButtonOrder.map(\.title) == ["Keep", "Delete"])

        let onlyDestructive = AppAlert(actions: [.init(title: "Delete", style: .destructive)])
        #expect(onlyDestructive.macButtonOrder.map(\.title) == ["Delete"])
    }

    @Test func theMessageStandsInForAMissingTitleOnTheMac() {
        #expect(AppAlert(title: "Title", message: "Body", actions: []).macTexts == ("Title", "Body"))
        #expect(AppAlert(message: "Body", actions: []).macTexts == ("Body", ""))
    }

    @MainActor @Test func thePreferredActionIsTheAlertControllersToo() {
        let controller = AppAlert(actions: [
            .init(title: "Cancel", style: .cancel),
            .init(title: "Open", isPreferred: true),
        ]).makeAlertController()

        #expect(controller.preferredAction?.title == "Open")
    }
}
