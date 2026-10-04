@testable import HomeAssistant
@testable import Shared
import SwiftUI
import UIKit
import XCTest

/// Lays the server list out in the states onboarding goes through: searching, servers found, and an
/// invitation link waiting to be accepted. Discovery runs against `MockBonjour`, so nothing touches
/// the network.
@MainActor
final class OnboardingServersListViewRenderTests: XCTestCase {
    private var previousBonjour: (() -> BonjourProtocol)!
    private var previousInviteURL: URL?
    private var bonjour: MockBonjour!
    private var window: UIWindow?

    override func setUp() {
        super.setUp()
        previousBonjour = Current.bonjour
        previousInviteURL = Current.appSessionValues.inviteURL
        Current.appSessionValues.inviteURL = nil
        let bonjour = MockBonjour()
        self.bonjour = bonjour
        Current.bonjour = { bonjour }
    }

    override func tearDown() {
        tearDownWindow()
        Current.bonjour = previousBonjour
        Current.appSessionValues.inviteURL = previousInviteURL
        super.tearDown()
    }

    func testSearchingStartsDiscoveryAndStopsItWhenHidden() {
        show(OnboardingServersListView(onboardingStyle: .initial, presenter: OnboardingAuthPresenter()))

        XCTAssertTrue(bonjour.startCalled)
        XCTAssertNotNil(bonjour.observer)

        tearDownWindow()
        XCTAssertTrue(bonjour.stopCalled)
    }

    func testListsTheDiscoveredServers() throws {
        show(OnboardingServersListView(onboardingStyle: .required, presenter: OnboardingAuthPresenter()))
        let observer = try XCTUnwrap(bonjour.observer)

        observer.bonjour(Bonjour(), didAdd: instance(name: "Home", url: "http://192.168.1.2:8123"))
        observer.bonjour(Bonjour(), didAdd: instance(name: "Cabin", url: "http://192.168.1.3:8123"))
        layout()

        observer.bonjour(Bonjour(), didRemoveInstanceWithName: "Cabin")
        layout()

        XCTAssertNotNil(window?.rootViewController?.view)
    }

    func testAddingAServerFromSettingsOffersCancel() {
        show(NavigationStack {
            OnboardingServersListView(
                shouldDismissOnSuccess: true,
                onboardingStyle: .secondary,
                presenter: OnboardingAuthPresenter()
            )
        })

        XCTAssertTrue(bonjour.startCalled)
    }

    func testShowsTheInvitationForAPrefilledURL() {
        show(NavigationStack {
            OnboardingServersListView(
                prefillURL: URL(string: "http://homeassistant.local:8123")!,
                onboardingStyle: .initial,
                presenter: OnboardingAuthPresenter()
            )
        })

        // Discovery still runs underneath the invitation: it is how the instance ID is found.
        XCTAssertTrue(bonjour.startCalled)
    }

    func testShowsTheInvitationFromTheSession() {
        Current.appSessionValues.inviteURL = URL(string: "http://192.168.1.2:8123")
        show(NavigationStack {
            OnboardingServersListView(onboardingStyle: .secondary, presenter: OnboardingAuthPresenter())
        })

        XCTAssertTrue(bonjour.startCalled)
    }

    // MARK: - Helpers

    private func instance(name: String, url: String) -> DiscoveredHomeAssistant {
        var instance = DiscoveredHomeAssistant(manualURL: URL(string: url)!, name: name)
        instance.bonjourName = name
        return instance
    }

    private func show(_ view: some View) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(rootView: view)
        window.isHidden = false
        self.window = window
        layout()
    }

    private func layout() {
        window?.rootViewController?.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        window?.rootViewController?.view.layoutIfNeeded()
    }

    private func tearDownWindow() {
        guard let window else { return }
        window.isHidden = true
        window.rootViewController = nil
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        self.window = nil
    }
}
