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
    @Published var shouldDismiss = false
    @Published var onboardingServer: Server?

    @Published var manualInputLoading = false
    @Published var invitationLoading = false
    @Published var showCenterLoader = true

    private var webhookSensors: [WebhookSensor] = []
    private var discovery = Current.bonjour()
    private var cancellables = Set<AnyCancellable>()
    private let shouldDismissOnSuccess: Bool

    init(shouldDismissOnSuccess: Bool) {
        self.shouldDismissOnSuccess = shouldDismissOnSuccess
        discovery.observer = self
        Current.sensors.register(observer: self)
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
        disableNonEssentialSensors(server)
        showPermissionsFlow = true
    }

    private func disableNonEssentialSensors(_ server: Server) {
        guard Current.servers.all.count == 1 else {
            Current.Log.verbose("Avoid overriding sensors if user has already servers setup in place.")
            return
        }
        let sensorsToKeepEnabled: [WebhookSensorId] = [
            .appVersion,
            .locationPermission,
        ]
        for sensor in webhookSensors {
            if let uniqueId = sensor.UniqueID,
               uniqueId.contains("battery") || sensorsToKeepEnabled.map(\.rawValue).contains(uniqueId) {
                Current.sensors.setEnabled(true, for: sensor)
            } else {
                Current.sensors.setEnabled(false, for: sensor)
            }
        }
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

extension OnboardingServersListViewModel: SensorObserver {
    func sensorContainer(
        _ container: Shared.SensorContainer,
        didSignalForUpdateBecause reason: Shared.SensorContainerUpdateReason
    ) {
        /* no-op */
    }

    func sensorContainer(_ container: SensorContainer, didUpdate update: SensorObserverUpdate) {
        update.sensors.done { [weak self] sensors in
            self?.webhookSensors = sensors
        }
    }
}

extension OnboardingServersListViewModel: OnboardingStateObserver {
    func onboardingStateDidChange(to state: OnboardingState) {
        if state == .complete, shouldDismissOnSuccess {
            shouldDismiss = true
        }
    }
}
