@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// Renders the server discovery list through each of its states: an invitation, discovered servers,
/// a manual URL being checked and a connection error. The list's view model is reached through the
/// mock discovery it registers itself with, so each state is set directly instead of waited for.
@Suite(.sharedState)
@MainActor
struct OnboardingServersListViewRenderTests {
    private struct Rendered {
        let controller: UIViewController
        let window: UIWindow
        let viewModel: OnboardingServersListViewModel?

        func relayout() async {
            for _ in 0 ..< 5 {
                await Task.yield()
            }
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
        }

        func tearDown() {
            window.isHidden = true
            window.rootViewController = nil
        }
    }

    private enum PlainError: Error {
        case failed
    }

    private func render(
        prefillURL: URL? = nil,
        style: OnboardingStyle,
        compact: Bool = false
    ) async -> Rendered {
        let bonjour = MockBonjour()
        let previousBonjour = Current.bonjour
        Current.bonjour = { bonjour }
        defer { Current.bonjour = previousBonjour }

        let view = NavigationStack {
            OnboardingServersListView(
                prefillURL: prefillURL,
                onboardingStyle: style,
                presenter: OnboardingAuthPresenter()
            )
        }
        .environment(\.verticalSizeClass, compact ? .compact : .regular)
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.layoutIfNeeded()

        let rendered = Rendered(
            controller: controller,
            window: window,
            viewModel: bonjour.observer as? OnboardingServersListViewModel
        )
        await rendered.relayout()
        return rendered
    }

    private func instances(_ count: Int) throws -> [DiscoveredHomeAssistant] {
        try (0 ..< count).map { index in
            try DiscoveredHomeAssistant(
                manualURL: #require(URL(string: "http://homeassistant-\(index).local:8123")),
                name: "Home \(index)"
            )
        }
    }

    @Test(arguments: [OnboardingStyle.initial, .required, .secondary])
    func rendersDiscoveredServersForEveryStyle(style: OnboardingStyle) async throws {
        let rendered = await render(style: style)
        defer { rendered.tearDown() }
        let viewModel = try #require(rendered.viewModel)

        viewModel.discoveredInstances = try instances(3)
        await rendered.relayout()

        viewModel.showCenterLoader = false
        viewModel.currentlyInstanceLoading = viewModel.discoveredInstances.first
        await rendered.relayout()

        viewModel.manualInputLoading = true
        await rendered.relayout()
        #expect(viewModel.discoveredInstances.count == 3)
    }

    @Test func rendersInACompactHeightWindow() async throws {
        let rendered = await render(style: .initial, compact: true)
        defer { rendered.tearDown() }
        let viewModel = try #require(rendered.viewModel)

        viewModel.discoveredInstances = try instances(2)
        viewModel.showCenterLoader = false
        await rendered.relayout()
    }

    @Test func aSingleDiscoveredServerWaitsToConnectAutomatically() async throws {
        let rendered = await render(style: .initial)
        defer { rendered.tearDown() }
        let viewModel = try #require(rendered.viewModel)

        viewModel.discoveredInstances = try instances(1)
        await rendered.relayout()
        viewModel.discoveredInstances = []
        await rendered.relayout()
    }

    @Test func rendersAConnectionError() async throws {
        let rendered = await render(style: .secondary)
        defer { rendered.tearDown() }
        let viewModel = try #require(rendered.viewModel)

        viewModel.error = PlainError.failed
        viewModel.showError = true
        await rendered.relayout()
        viewModel.showError = false
        await rendered.relayout()
    }

    @Test(arguments: [OnboardingStyle.initial, .secondary])
    func rendersAnInvitation(style: OnboardingStyle) async throws {
        let rendered = await render(
            prefillURL: URL(string: "http://homeassistant.local:8123"),
            style: style
        )
        defer { rendered.tearDown() }
        let viewModel = try #require(rendered.viewModel)

        viewModel.invitationLoading = true
        await rendered.relayout()
        #expect(viewModel.invitationLoading)
    }
}
