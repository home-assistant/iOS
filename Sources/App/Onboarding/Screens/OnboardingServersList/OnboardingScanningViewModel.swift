import Combine
import Foundation
import Shared

final class OnboardingScanningViewModel: ObservableObject {
    @Published var discoveredInstances: [DiscoveredHomeAssistant] = []
    private let discovery = Bonjour()
    private var cancellables = Set<AnyCancellable>()

    init() {
        discovery.observer = self
    }

    func startDiscovery() {
        discoveredInstances = []
        discovery.start()
    }

    func stopDiscovery() {
        discovery.stop()
    }

    func selectInstance(_ instance: DiscoveredHomeAssistant) {
        // Handle instance selection
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
