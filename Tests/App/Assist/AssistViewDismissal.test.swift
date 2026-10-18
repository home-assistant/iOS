@testable import HomeAssistant
@testable import Shared
import SwiftUI
import UIKit
import XCTest

@MainActor
final class AssistViewDismissalTests: XCTestCase {
    /// Whoever presented Assist relies on hearing when it leaves the screen to catch up on what it covered.
    func testLeavingTheScreenRunsOnDismiss() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let dismissed = expectation(description: "onDismiss runs")
        let viewModel = AssistViewModel(
            server: ServerFixture.standard,
            audioRecorder: MockAudioRecorder(),
            audioPlayer: MockAudioPlayer(),
            assistService: MockAssistService(),
            autoStartRecording: false
        )
        window.rootViewController = UIHostingController(rootView: AssistView(
            viewModel: viewModel,
            onDismiss: { dismissed.fulfill() }
        ))
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))

        window.rootViewController = nil
        window.isHidden = true

        wait(for: [dismissed], timeout: 5)
    }
}
