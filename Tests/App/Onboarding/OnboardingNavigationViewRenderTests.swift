@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// The onboarding container: each page the auth flow pushes onto its stack, the prompts it presents
/// over them (certificate trust, client certificate import, server identity), and the presenter
/// calls that drive them.
@Suite(.sharedState)
@MainActor
struct OnboardingNavigationViewRenderTests {
    private enum PlainError: Error {
        case failed
    }

    private struct Hosted {
        let controller: UIViewController
        let window: UIWindow

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

    private func withMockDiscovery(_ body: () async throws -> Void) async rethrows {
        let previousBonjour = Current.bonjour
        Current.bonjour = { MockBonjour() }
        defer { Current.bonjour = previousBonjour }
        try await body()
    }

    private func host(style: OnboardingStyle, presenter: OnboardingAuthPresenter) -> Hosted {
        let controller = UIHostingController(rootView: OnboardingNavigationView(
            onboardingStyle: style,
            presenter: presenter
        ))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.layoutIfNeeded()
        return Hosted(controller: controller, window: window)
    }

    private func identityRequest() -> OnboardingServerIdentityRequest {
        OnboardingServerIdentityRequest(
            newServer: ServerIdentityConflictingServer(name: "Chalet", address: nil),
            existingServer: ServerIdentityConflictingServer(name: "Home", address: nil),
            onDecision: { _ in },
            onCancel: {}
        )
    }

    @Test(arguments: [OnboardingStyle.initial, .required, .secondary])
    func rendersTheRootForEveryStyle(style: OnboardingStyle) async {
        await withMockDiscovery {
            let presenter = OnboardingAuthPresenter()
            let hosted = host(style: style, presenter: presenter)
            defer { hosted.tearDown() }
            await hosted.relayout()
            #expect(presenter.path.isEmpty)
        }
    }

    @Test func rendersEachPageTheFlowPushes() async throws {
        try await withMockDiscovery {
            let presenter = OnboardingAuthPresenter()
            let hosted = host(style: .initial, presenter: presenter)
            defer { hosted.tearDown() }

            let destinations: [OnboardingDestination] = [
                .serversList,
                .connectionError(OnboardingConnectionErrorContext(error: PlainError.failed)),
                .clientCertificate(OnboardingClientCertificateRequest(onImport: { _ in }, onCancel: {})),
                .deviceName(OnboardingDeviceNameRequest(onSave: { _, _ in }, onCancel: {})),
                .serverIdentity(identityRequest()),
                .permissions(.fake()),
            ]
            for destination in destinations {
                presenter.push(destination)
                await hosted.relayout()
            }
            #expect(presenter.path.count == destinations.count)

            presenter.popAuthFlow()
            #expect(presenter.path.allSatisfy { !$0.isAuthFlowStep })
            await hosted.relayout()

            presenter.popToRoot()
            #expect(presenter.path.isEmpty)
            await hosted.relayout()
        }
    }

    @Test func presentsAndDismissesThePrompts() async {
        await withMockDiscovery {
            let presenter = OnboardingAuthPresenter()
            let hosted = host(style: .secondary, presenter: presenter)
            defer { hosted.tearDown() }

            presenter.present(certificateTrustRequest: OnboardingCertificateTrustRequest(
                message: "Untrusted certificate",
                onTrust: {},
                onDontTrust: {}
            ))
            await hosted.relayout()
            #expect(presenter.certificateTrustRequest != nil)
            presenter.certificateTrustRequest = nil

            presenter.holdClientCertificateSheet = true
            presenter.present(clientCertificateRequest: OnboardingClientCertificateRequest(
                onImport: { _ in },
                onCancel: {}
            ))
            await hosted.relayout()
            presenter.releaseClientCertificateHold()
            #expect(!presenter.holdClientCertificateSheet)
            await hosted.relayout()
            presenter.dismissClientCertificateRequest()
            #expect(presenter.clientCertificateRequest == nil)
            await hosted.relayout()

            presenter.present(serverIdentityRequest: identityRequest())
            #expect(presenter.serverIdentityRequest != nil)
            await hosted.relayout()
            presenter.dismissServerIdentityRequest()
            #expect(presenter.serverIdentityRequest == nil)
            await hosted.relayout()
        }
    }

    @Test func destinationsAreEqualOnlyToTheSameStep() {
        let error = OnboardingConnectionErrorContext(error: PlainError.failed)
        let certificate = OnboardingClientCertificateRequest(onImport: { _ in }, onCancel: {})
        let deviceName = OnboardingDeviceNameRequest(onSave: { _, _ in }, onCancel: {})
        let identity = identityRequest()
        let server = Server.fake()
        let destinations: [OnboardingDestination] = [
            .serversList,
            .connectionError(error),
            .clientCertificate(certificate),
            .deviceName(deviceName),
            .serverIdentity(identity),
            .permissions(server),
        ]

        for (index, destination) in destinations.enumerated() {
            for (otherIndex, other) in destinations.enumerated() {
                #expect((destination == other) == (index == otherIndex))
            }
        }
        #expect(Set(destinations).count == destinations.count)
        #expect(OnboardingDestination.permissions(server) == .permissions(server))
        #expect(OnboardingDestination.connectionError(error) != .connectionError(.init(error: PlainError.failed)))
        #expect(destinations.map(\.isAuthFlowStep) == [false, false, true, true, true, true])
    }

    @Test func onboardingIsRequiredOnlyWithoutServers() {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }

        Current.servers = FakeServerManager(initial: 0)
        #expect(OnboardingNavigation.requiredOnboardingStyle == .required)
        Current.servers = FakeServerManager(initial: 1)
        #expect(OnboardingNavigation.requiredOnboardingStyle == nil)
    }
}
