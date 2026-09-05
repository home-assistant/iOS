import Combine
import Foundation
import PromiseKit
import Shared
import SwiftUI

final class OnboardingServersListViewModel: ObservableObject {
    enum Destination {
        case error(Error)
        case next(Server)
    }

    @Published var discoveredInstances: [DiscoveredHomeAssistant] = []
    @Published var currentlyInstanceLoading: DiscoveredHomeAssistant?

    @Published var showError = false
    @Published var error: Error?

    @Published var shouldDismiss = false
    @Published var onboardingServer: Server?

    @Published var manualInputLoading = false
    @Published var invitationLoading = false
    @Published var showCenterLoader = true

    var pendingManualURL: URL?

    private var discovery = Current.bonjour()
    private var cancellables = Set<AnyCancellable>()
    private let shouldDismissOnSuccess: Bool
    /// The presenter driving the auth flow's pushed screens; owned by the view, set for each attempt.
    private weak var authPresenter: OnboardingAuthPresenter?

    init(shouldDismissOnSuccess: Bool) {
        self.shouldDismissOnSuccess = shouldDismissOnSuccess
        discovery.observer = self
        Current.onboardingObservation.register(observer: self)
    }

    func startDiscovery() {
        discoveredInstances = []
        discovery.start()

        if Current.appConfiguration == .debug {
            for (idx, instance) in [
                DiscoveredHomeAssistant(
                    manualURL: URL(string: "https://jigsaw.w3.org/HTTP/Basic")!,
                    name: "Basic Auth"
                ),
                DiscoveredHomeAssistant(
                    manualURL: URL(string: "http://httpbin.org/digest-auth/asdf")!,
                    name: "Digest Auth"
                ),
                DiscoveredHomeAssistant(
                    manualURL: URL(string: "https://self-signed.badssl.com/")!,
                    name: "Self signed SSL"
                ),
                DiscoveredHomeAssistant(
                    manualURL: URL(string: "https://client.badssl.com/")!,
                    name: "Client Cert"
                ),
                DiscoveredHomeAssistant(
                    manualURL: URL(string: "https://expired.badssl.com/")!,
                    name: "Expired"
                ),
                DiscoveredHomeAssistant(
                    manualURL: URL(string: "https://httpbin.org/statuses/404")!,
                    name: "Status Code 404"
                ),
            ].enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1500 * (idx + 1))) { [weak self] in
                    self?.discoveredInstances.append(instance)
                }
            }
        }
    }

    func stopDiscovery() {
        discovery.stop()
    }

    /// Restarts discovery without clearing already-discovered instances — used when the servers list
    /// reappears after an auth flow page above it was popped (being covered stops discovery).
    func resumeDiscovery() {
        discovery.start()
    }

    func selectInstance(_ instance: DiscoveredHomeAssistant, presenter: OnboardingAuthPresenter) {
        Current.Log.verbose("Selected instance \(instance)")

        currentlyInstanceLoading = instance
        authPresenter = presenter

        let authentication = OnboardingAuth()

        authentication.authenticate(to: instance, presenter: presenter).pipe { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case let .fulfilled(server):
                    Current.Log.verbose("Onboarding authentication succeeded")
                    self?.authenticationSucceeded(server: server)
                case let .rejected(error):
                    // The flow is over; pop whatever auth pages are still pushed.
                    presenter.popAuthFlow()
                    if let pmkError = error as? PMKError, pmkError.isCancelled {
                        /* No action needed, user cancelled flow */
                        self?.resetFlow()
                    } else if Current.isCatalyst {
                        // Pushed in the same update as the pop above so the path change is atomic;
                        // a sheet is not used here because sheets don't receive mouse events
                        // reliably on Mac Catalyst.
                        self?.resetFlow()
                        presenter.push(.connectionError(.init(error: error)))
                    } else {
                        self?.error = error
                        self?.showError = true
                    }
                }
                self?.resetSpecificLoaders()
            }
        }
    }

    private func resetSpecificLoaders() {
        manualInputLoading = false
        invitationLoading = false
    }

    func resetFlow() {
        currentlyInstanceLoading = nil
        resetSpecificLoaders()
    }

    @MainActor
    private func authenticationSucceeded(server: Server) {
        discovery.stop()
        onboardingServer = server
        clearSensorSelectionForFirstRun()
        // Advance the pushed auth flow directly into the permissions steps.
        authPresenter?.push(.permissions(server))
    }

    /// Every sensor is opt-in, so a first-time install starts with an empty selection and reports
    /// only what the user switches on afterwards.
    private func clearSensorSelectionForFirstRun() {
        guard Current.servers.all.count == 1 else {
            Current.Log.verbose("Avoid overriding sensors if user has already servers setup in place.")
            return
        }
        Current.sensors.resetSensorsForFirstRun()
    }
}

extension OnboardingServersListViewModel: BonjourObserver {
    func bonjour(_ bonjour: Bonjour, didAdd instance: DiscoveredHomeAssistant) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Prevent duplicates by checking if instance already exists
            if !discoveredInstances.contains(instance) {
                discoveredInstances.append(instance)
            }
        }
    }

    func bonjour(_ bonjour: Bonjour, didRemoveInstanceWithName name: String) {
        DispatchQueue.main.async { [weak self] in
            self?.discoveredInstances.removeAll { $0.bonjourName == name }
        }
    }
}

extension OnboardingServersListViewModel: OnboardingStateObserver {
    func onboardingStateDidChange(to state: OnboardingState) {
        guard state == .complete else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if shouldDismissOnSuccess {
                shouldDismiss = true
            }
            if let onboardingServer {
                Current.appDatabaseUpdater.update(server: onboardingServer, forceUpdate: true, showProgress: false)
            }
        }
    }
}
