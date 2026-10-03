import Foundation
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// iOS smoke tests: lays out the frontend's companion screens so a body that stops building is caught
/// here. What the Mac draws is checked by hand on a Mac.
// Serialized: the tests swap `Current.servers`, which concurrent tests would race on.
@MainActor
@Suite(.serialized)
struct FrontendScreensRenderTests {
    private func withFakeServers(_ body: () throws -> Void) rethrows {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 1)
        try body()
    }

    @Test func connectionErrorDetails() {
        withFakeServers {
            renderInWindow(NavigationView {
                ConnectionErrorDetailsView(
                    server: Current.servers.all[0],
                    error: URLError(.notConnectedToInternet),
                    expandMoreDetails: true
                )
            }, height: 2400)
        }
    }

    @available(iOS 17, *)
    @Test func downloadManagerWhileDownloadingAndOnceFinished() {
        let viewModel = DownloadManagerViewModel()
        viewModel.fileName = "backup.tar"
        viewModel.progress = "40%"
        renderInWindow(DownloadManagerView(viewModel: viewModel))

        viewModel.finished = true
        renderInWindow(DownloadManagerView(viewModel: viewModel))
    }

    @Test func serverSelectionList() {
        withFakeServers {
            renderInWindow(ServerSelectionListView(prompt: nil, selectAction: { _ in }, expandAction: {}))
        }
    }

    @Test func widgetSelection() {
        withFakeServers {
            renderInWindow(WidgetSelectionView(
                entityId: "light.kitchen",
                serverId: Current.servers.all[0].identifier.rawValue,
                onSelection: { _ in }
            ))
        }
    }

    @Test func checkmarkDrawOn() {
        renderInWindow(CheckmarkDrawOnView())
    }

    @Test func jinjaEntitySuggestions() {
        let items = [
            JinjaEntitySuggestionsView.Item(
                suggestion: JinjaTemplateSuggestion(label: "light.kitchen", insertion: "light.kitchen"),
                name: "Kitchen",
                subtitle: "light.kitchen"
            ),
            JinjaEntitySuggestionsView.Item(
                suggestion: JinjaTemplateSuggestion(label: "sensor.temperature", insertion: "sensor.temperature"),
                name: "Temperature",
                subtitle: nil
            ),
        ]
        renderInWindow(JinjaEntitySuggestionsView(items: items, onSelect: { _ in }, onMore: {}))
    }
}
