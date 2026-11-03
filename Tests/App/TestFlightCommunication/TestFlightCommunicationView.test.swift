import Foundation
@testable import HomeAssistant
import SFSafeSymbols
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Renders the TestFlight message sheet with and without a call to action and with both kinds of
/// item icon, and records the view once it appears.
@MainActor
struct TestFlightCommunicationViewTests {
    private func message(callToAction: TestFlightMessage.CallToAction?) -> TestFlightMessage {
        TestFlightMessage(
            id: TestFlightMessageId("test-message"),
            title: "Help us test",
            items: [
                WhatsNewItem(id: "One", title: "One", body: "First", icon: .sfSymbol(.testtube2)),
                WhatsNewItem(id: "Two", title: "Two", body: "Second", icon: .materialDesign(.homeAssistantIcon)),
                WhatsNewItem(id: "Three", title: "Three", body: "Third", icon: .sfSymbol(.star)),
                WhatsNewItem(id: "Four", title: "Four", body: "Fourth", icon: .sfSymbol(.heart)),
                WhatsNewItem(id: "Five", title: "Five", body: "Fifth", icon: .sfSymbol(.bell)),
                WhatsNewItem(id: "Six", title: "Six", body: "Sixth", icon: .materialDesign(.lightbulbIcon)),
            ],
            callToAction: callToAction
        )
    }

    private func render(_ message: TestFlightMessage) async -> Int {
        var viewed = 0
        let host = UIHostingController(rootView: TestFlightCommunicationView(message: message, onViewed: {
            viewed += 1
        }))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1400))
        window.rootViewController = host
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        let deadline = Date().addingTimeInterval(10)
        while viewed == 0, Date() < deadline {
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        // Further layout passes don't record the view again.
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        return viewed
    }

    @Test func rendersWithACallToAction() async throws {
        let url = try #require(URL(string: "https://www.home-assistant.io/beta"))
        let viewed = await render(message(callToAction: .init(title: "Give feedback", url: url)))
        #expect(viewed == 1)
    }

    @Test func rendersWithoutACallToAction() async {
        let viewed = await render(message(callToAction: nil))
        #expect(viewed == 1)
    }
}
