@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// The sheet that asks before firing an NFC tag the app hasn't seen: it renders the tag with its
/// copy button and the allow once / allow always choices, short and long identifiers alike.
@MainActor
struct TagApprovalBottomSheetTests {
    private final class Recorder {
        var calls: [String] = []
    }

    private func render(tag: String, recorder: Recorder) {
        let controller = UIHostingController(rootView: TagApprovalBottomSheet(
            tag: tag,
            onAllowOnce: { recorder.calls.append("once") },
            onAllowAlways: { recorder.calls.append("always") },
            onDismiss: { recorder.calls.append("dismiss") }
        ))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        window.isHidden = true
        window.rootViewController = nil
    }

    @Test(arguments: ["04-A2", String(repeating: "04-A2-B3-C4-D5-E6-", count: 8)])
    func rendersWithoutRunningAnyChoice(tag: String) {
        let recorder = Recorder()
        render(tag: tag, recorder: recorder)
        // Nothing is allowed until the person picks a choice.
        #expect(!recorder.calls.contains("once"))
        #expect(!recorder.calls.contains("always"))
    }
}
