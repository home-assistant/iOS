import Combine
import Foundation
import Shared
import SwiftUI

final class OnboardingScanningViewModel: ObservableObject {
    enum Destination {
        case error(Error)
        case next
    }

    @Published var discoveredInstances: [DiscoveredHomeAssistant] = []
    @Published var currentlyInstanceLoading: DiscoveredHomeAssistant?
    @Published var nextDestination: Destination?

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

    func selectInstance(_ instance: DiscoveredHomeAssistant) {
        Current.Log.verbose("Selected instance \(instance)")

        currentlyInstanceLoading = instance

        let authentication = OnboardingAuth()
        guard let topViewController = UIApplication.shared.windows.first?.rootViewController else { return }

        authentication.authenticate(to: instance, sender: topViewController).pipe { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case let .fulfilled(server):
                    self?.nextDestination = .next // AnyView(OnboardinSuccessController(server: server))
                case let .rejected(error):
                    self?.nextDestination = .error(error)
                }
                self?.isLoading = false
            }
        }
    }

    func resetFlow() {
        nextDestination = nil
        currentlyInstanceLoading = nil
        isLoading = false
    }
}

extension OnboardingScanningViewModel: BonjourObserver {
    func bonjour(_ bonjour: Bonjour, didAdd instance: DiscoveredHomeAssistant) {
        discoveredInstances.append(instance)
    }

    func bonjour(_ bonjour: Bonjour, didRemoveInstanceWithName name: String) {
        discoveredInstances.removeAll { $0.bonjourName == name }
    }
}
