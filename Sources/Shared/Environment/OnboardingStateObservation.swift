import Foundation

public enum OnboardingState {
    public enum NeededType {
        case logout
        case error
        case unauthenticated(_ serverId: String, _ code: Int)

        public var shouldShowError: Bool {
            switch self {
            case .logout: return false
            case .error: return true
            case .unauthenticated: return false
            }
        }
    }

    case complete
    case didConnect
    case needed(NeededType)
}

public protocol OnboardingStateObserver: AnyObject {
    func onboardingStateDidChange(to state: OnboardingState)
}

public class OnboardingStateObservation {
    private var observers = NSHashTable<AnyObject>(options: .weakMemory)

    public func register(observer: OnboardingStateObserver) {
        observers.add(observer)
    }

    public func unregister(observer: OnboardingStateObserver) {
        observers.remove(observer)
    }

    private func notify(for state: OnboardingState) {
        observers
            .allObjects
            .compactMap { $0 as? OnboardingStateObserver }
            .forEach { $0.onboardingStateDidChange(to: state) }
    }

    public func complete() {
        notify(for: .complete)
    }

    public func needed(_ type: OnboardingState.NeededType) {
        notify(for: .needed(type))
    }

    public func didConnect() {
        notify(for: .didConnect)
    }
}
