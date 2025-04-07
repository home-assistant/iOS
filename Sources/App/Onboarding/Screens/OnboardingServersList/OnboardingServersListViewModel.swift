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

    @Published var showPermissionsFlow = false
    @Published var onboardingServer: Server?

    /// Indicator for manual input loading
    @Published var isLoading = false

    private let discovery = Bonjour()
    private var cancellables = Set<AnyCancellable>()

    init() {
        discovery.observer = self
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

    func selectInstance(_ instance: DiscoveredHomeAssistant, controller: UIViewController?) {
        guard let controller else {
            Current.Log.error("No controller provided for onboarding")
            return
        }
        Current.Log.verbose("Selected instance \(instance)")

        currentlyInstanceLoading = instance

        let authentication = OnboardingAuth()

        authentication.authenticate(to: instance, sender: controller).pipe { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case let .fulfilled(server):
                    Current.Log.verbose("Onboarding authentication succeeded")
                    self?.authenticationSucceeded(server: server)
                case let .rejected(error):
                    self?.error = error
                    self?.showError = true
                }
                self?.isLoading = false
            }
        }
    }

    func resetFlow() {
        currentlyInstanceLoading = nil
        isLoading = false
    }

    @MainActor
    private func authenticationSucceeded(server: Server) {
        discovery.stop()
        onboardingServer = server
        showPermissionsFlow = true
    }
}

extension OnboardingServersListViewModel: BonjourObserver {
    func bonjour(_ bonjour: Bonjour, didAdd instance: DiscoveredHomeAssistant) {
        DispatchQueue.main.async { [weak self] in
            self?.discoveredInstances.append(instance)
        }
    }

    func bonjour(_ bonjour: Bonjour, didRemoveInstanceWithName name: String) {
        DispatchQueue.main.async { [weak self] in
            self?.discoveredInstances.removeAll { $0.bonjourName == name }
        }
    }
}
