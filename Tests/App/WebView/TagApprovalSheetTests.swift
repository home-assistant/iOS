@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// The sheet that asks before firing an NFC tag the app hasn't seen: it renders the tag with its
/// copy button and the allow once / allow always choices, short and long identifiers alike.
@MainActor
struct TagApprovalSheetTests {
    private final class Recorder {
        var calls: [String] = []
    }

    private func makeView(tag: String, recorder: Recorder) -> TagApprovalSheet {
        TagApprovalSheet(
            tag: tag,
            onAllowOnce: { recorder.calls.append("once") },
            onAllowAlways: { recorder.calls.append("always") },
            onDismiss: { recorder.calls.append("dismiss") }
        )
    }

    @Test(arguments: ["04-A2", String(repeating: "04-A2-B3-C4-D5-E6-", count: 8)])
    func rendersWithoutRunningAnyChoice(tag: String) async {
        let recorder = Recorder()
        let driver = await SwiftUIScreenDriver.show(
            makeView(tag: tag, recorder: recorder),
            size: CGSize(width: 390, height: 844),
            inNavigationStack: false
        )
        defer { driver.close() }
        await #expect(driver.waitUntil { driver.presented != nil })
        // Nothing is allowed until the person picks a choice.
        #expect(!recorder.calls.contains("once"))
        #expect(!recorder.calls.contains("always"))
        #expect(!recorder.calls.contains("dismiss"))
    }

    @Test(arguments: zip(
        ["once", "always"],
        [L10n.Nfc.TagApproval.allowOnce, L10n.Nfc.TagApproval.allowAlways]
    ))
    func choosingAnOptionReportsItAndCloses(choice: String, title: String) async {
        let recorder = Recorder()
        let driver = await SwiftUIScreenDriver.show(
            makeView(tag: "04-A2", recorder: recorder),
            size: CGSize(width: 390, height: 844),
            inNavigationStack: false
        )
        defer { driver.close() }
        await #expect(driver.waitUntil { driver.presented != nil })

        await #expect(driver.tapButton(titled: title))
        await #expect(driver.waitUntil { driver.presented == nil })
        #expect(recorder.calls == [choice, "dismiss"])
    }

    @Test func copyingTheTagPutsItOnThePasteboard() async {
        let recorder = Recorder()
        let tag = "04-A2-B3-C4"
        let driver = await SwiftUIScreenDriver.show(
            makeView(tag: tag, recorder: recorder),
            size: CGSize(width: 390, height: 844),
            inNavigationStack: false
        )
        defer { driver.close() }
        await #expect(driver.waitUntil { driver.presented != nil })
        UIPasteboard.general.string = ""

        await #expect(driver.tapButton(titled: L10n.Nfc.TagApproval.copyTag))
        #expect(UIPasteboard.general.string == tag)
        #expect(driver.presented != nil)
        #expect(recorder.calls.isEmpty)
    }

    @Test func closingTheSheetReportsDismissAndDismissesTheHost() async {
        let recorder = Recorder()
        let driver = await SwiftUIScreenDriver.show(
            Color.clear,
            size: CGSize(width: 390, height: 844),
            inNavigationStack: false
        )
        defer { driver.close() }

        let host = UIHostingController(rootView: AnyView(EmptyView()))
        host.rootView = AnyView(TagApprovalSheet(
            tag: "04-A2",
            onAllowOnce: { recorder.calls.append("once") },
            onAllowAlways: { recorder.calls.append("always") },
            onDismiss: { [weak host] in
                recorder.calls.append("dismiss")
                host?.dismiss(animated: false)
            }
        ))
        host.modalPresentationStyle = .overFullScreen
        driver.host.present(host, animated: false)
        await #expect(driver.waitUntil { host.presentedViewController != nil })

        await #expect(driver.waitUntil { driver.barButtons.count == 1 })
        await driver.tapBarButton(0)
        await #expect(driver.waitUntil { host.presentingViewController == nil })
        #expect(driver.presented == nil)
        #expect(recorder.calls == ["dismiss"])
    }
}
