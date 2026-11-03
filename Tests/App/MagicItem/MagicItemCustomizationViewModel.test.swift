import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// The icon color on the customization screen is either "Default", which leaves the entity the color
/// the frontend gives it for its state, or "Custom", which fixes it to the color picked below.
struct MagicItemCustomizationViewModelTests {
    private func viewModel(customization: MagicItem.Customization = .init()) -> MagicItemCustomizationViewModel {
        .init(item: .init(id: "light.kitchen", serverId: "1", type: .entity, customization: customization))
    }

    @Test func anItemWithoutAPickedColorIsOnDefault() {
        let viewModel = viewModel()

        #expect(viewModel.usesCustomIconColor == false)
    }

    /// The tint the app wrote into older items on its own was never a choice.
    @Test func anItemSeededWithTheFormerTintIsOnDefault() {
        let viewModel = viewModel(customization: .init(iconColor: "00AEF8"))

        #expect(viewModel.usesCustomIconColor == false)
    }

    @Test func choosingCustomStartsFromTheAppTint() {
        let viewModel = viewModel()

        viewModel.usesCustomIconColor = true

        #expect(viewModel.usesCustomIconColor)
        #expect(viewModel.item.customization?.iconColor == MagicItem.defaultIconColorHex)
        #expect(viewModel.item.customization?.iconColorIsCustomized == true)
        #expect(viewModel.customIconColor.hex() == Color(hex: MagicItem.defaultIconColorHex).hex())
    }

    @Test func pickingAColorFixesTheIconToIt() {
        let viewModel = viewModel()
        viewModel.usesCustomIconColor = true

        viewModel.customIconColor = Color(hex: "#FF9800")

        #expect(viewModel.item.customization?.customIconColor == "FF9800")
        #expect(viewModel.customIconColor.hex() == "FF9800")
    }

    @Test func choosingDefaultDropsThePickedColor() {
        let viewModel = viewModel(customization: .init(iconColor: "#FF9800", iconColorIsCustomized: true))

        viewModel.usesCustomIconColor = false

        #expect(viewModel.usesCustomIconColor == false)
        #expect(viewModel.item.customization?.iconColor == nil)
        #expect(viewModel.item.customization?.iconColorIsCustomized == false)
    }

    /// A cover's on/off pair depends on its `supported_features`, which are read from its server.
    /// `.sharedState`: the test swaps `Current.servers` and the cached API.
    @MainActor
    @Test(.sharedState) func readsACoversSupportedFeaturesFromItsServer() async {
        let previousServers = Current.servers
        let servers = FakeServerManager(initial: 1)
        let server = servers.all[0]
        let connection = HAMockConnection()
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.servers = servers
        Current.setCachedApi(api, for: server.identifier)
        defer {
            // Settle whatever is still pending so no load stays suspended on it.
            let leftovers = connection.pendingRequests
            connection.pendingRequests.removeAll()
            leftovers.forEach { $0.completion(.failure(.internal(debugDescription: "test ended"))) }
            Current.resetAPICache(for: [server.identifier])
            Current.servers = previousServers
        }

        let viewModel = MagicItemCustomizationViewModel(
            item: .init(id: "cover.garage", serverId: server.identifier.rawValue, type: .entity)
        )
        let progress = LoadProgress()
        let loading = Task { @MainActor in
            await viewModel.loadSupportedFeatures()
            progress.finished = true
        }
        defer { loading.cancel() }

        // Answer every request as soon as it arrives, until the load returns or the deadline passes, so
        // a late request is still answered and a load that never returns fails instead of hanging.
        let deadline = Date().addingTimeInterval(10)
        while !progress.finished, Date() < deadline {
            let requests = connection.pendingRequests
            connection.pendingRequests.removeAll()
            for request in requests {
                progress.requests.append(request.request)
                request.completion(.success(.dictionary(["attributes": ["supported_features": 3]])))
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        #expect(progress.finished)
        #expect(progress.requests.count == 1)
        #expect(viewModel.supportedFeatures == 3)
    }
}

/// What the load under test did, recorded on the main actor.
@MainActor
private final class LoadProgress {
    var finished = false
    var requests: [HARequest] = []
}
