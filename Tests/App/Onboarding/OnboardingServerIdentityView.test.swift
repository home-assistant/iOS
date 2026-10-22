@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct OnboardingServerIdentityViewTests {
    private static let home = ServerIdentityConflictingServer(
        name: "Domicile",
        address: "http://homeassistant.local:8123"
    )
    private static let chalet = ServerIdentityConflictingServer(
        name: "Chalet Hétu",
        address: "http://chalethetu.duckdns.org:8123"
    )

    private func makeRequest() -> OnboardingServerIdentityRequest {
        OnboardingServerIdentityRequest(
            newServer: Self.chalet,
            existingServer: Self.home,
            onDecision: { _ in },
            onCancel: {}
        )
    }

    /// Lays the view out in a window so SwiftUI resolves navigation destinations and presentations,
    /// without making it the key window the snapshot helpers draw into.
    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
    }

    @Test func serverIdentityPrompt() {
        guard #available(iOS 18.0, *) else { return }

        assertLightDarkSnapshots(of: NavigationStack { OnboardingServerIdentityView(request: makeRequest()) })
    }

    @Test func serverIdentityPromptSheet() {
        guard #available(iOS 18.0, *) else { return }

        assertLightDarkSnapshots(of: OnboardingServerIdentitySheet(request: makeRequest()))
    }

    @Test func serverIdentityExplanationForOnePair() {
        guard #available(iOS 18.0, *) else { return }

        assertLightDarkSnapshots(
            of: NavigationStack { ServerIdentityExplanationView(conflictingServers: [[Self.chalet, Self.home]]) },
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: 390, height: 1200)
        )
    }

    /// Two unrelated pairs each sharing an ID are listed apart, and a server without an address
    /// shows its name alone.
    @Test func serverIdentityExplanationForTwoGroups() {
        guard #available(iOS 18.0, *) else { return }

        let groups = [
            [Self.home, Self.chalet],
            [
                ServerIdentityConflictingServer(name: "Office", address: nil),
                ServerIdentityConflictingServer(name: "Office copy", address: "https://office.example.com"),
            ],
        ]

        assertLightDarkSnapshots(
            of: NavigationStack { ServerIdentityExplanationView(conflictingServers: groups) },
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: 390, height: 1500)
        )
    }

    /// Mac Catalyst pushes the question onto the onboarding stack instead of presenting a sheet.
    @Test func onboardingShowsTheQuestionAsAPushedPage() {
        let presenter = OnboardingAuthPresenter()
        let request = makeRequest()
        presenter.path = [.serverIdentity(request)]

        render(OnboardingNavigationView(onboardingStyle: .initial, presenter: presenter))

        #expect(presenter.path == [.serverIdentity(request)])
    }

    @Test func onboardingPresentsTheQuestionAsASheet() {
        let presenter = OnboardingAuthPresenter()
        presenter.serverIdentityRequest = makeRequest()

        render(OnboardingNavigationView(onboardingStyle: .initial, presenter: presenter))

        #expect(presenter.path.isEmpty)
    }
}
