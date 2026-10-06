import Foundation
@testable import HomeAssistant
import Shared
import Testing
import UIKit

@MainActor
struct HomeAssistantViewModelNotificationsTests {
    @Test("The sidebar's bell asks the frontend to close its drawer and opens it when nothing was open")
    func bellTogglesTheDrawer() async throws {
        let webViewController = WebViewController(server: ServerFixture.standard)
        webViewController.loadViewIfNeeded()
        let handler = MockWebViewExternalMessageHandler()
        webViewController.webViewExternalMessageHandler = handler
        let viewModel = HomeAssistantViewModel(server: ServerFixture.standard)
        viewModel.webViewController = webViewController

        viewModel.sidebar.onShowNotifications?()

        for _ in 0 ..< 200 where !handler.sendExternalBusCommandWithRetryCalled {
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(handler.sendExternalBusCommandWithRetryCalled)
        #expect(handler.sendExternalBusCommandWithRetryCommand == .showNotifications)
        withExtendedLifetime((webViewController, viewModel)) {}
    }

    @Test("Without a frontend on screen the bell does nothing")
    func bellWithoutAFrontend() {
        let viewModel = HomeAssistantViewModel(server: ServerFixture.standard)
        viewModel.sidebar.onShowNotifications?()
        #expect(viewModel.webViewController == nil)
    }
}
