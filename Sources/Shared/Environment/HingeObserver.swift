import Combine
import Foundation

/// Holds the latest hinge reading for the running app.
///
/// A hinge can only be observed from a view in the hierarchy — UIKit delivers it through a
/// `UIHingeInteraction`, SwiftUI through `onHingeChange` — so the app attaches the interaction and
/// hands each update here, and the sensor reads it back. That is also why the hinge sensors are
/// marked as only updating while the app is open: nothing feeds this while the app is away.
public final class HingeObserver: ObservableObject {
    /// The last reading the app saw, or `nil` when no hinge has been reported yet — either because
    /// the device has none, or because nothing has observed one yet this launch.
    @Published public private(set) var state: HingeState?

    /// Whether anything has reported a hinge yet, whatever it reported.
    ///
    /// This is what tells a device with no hinge apart from one nothing has observed yet: the
    /// interaction's handler runs once with the initial state as soon as it is attached, so a
    /// device that has a hinge reports one immediately, and `true` with a `nil` ``state`` means
    /// this device has none.
    @Published public private(set) var hasReceivedUpdate = false

    /// Emits the current reading and every subsequent change, so the hinge sensors can report it.
    public var statePublisher: AnyPublisher<HingeState?, Never> {
        $state.eraseToAnyPublisher()
    }

    /// Whether this device could ever report a hinge, which on anything older than the API is no.
    ///
    /// Injected rather than checked where it is used, so the sensor's behaviour on a device that
    /// supports hinges is testable on a simulator that does not.
    public let isSupported: Bool

    public init(isSupported: Bool = HingeObserver.systemSupportsHinge) {
        self.isSupported = isSupported
    }

    /// Whether the running OS has the hinge API at all.
    public static var systemSupportsHinge: Bool {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if #available(iOS 27.1, *) {
            return true
        }
        return false
        #else
        return false
        #endif
    }

    /// Called by whatever is observing the hinge, with `nil` when it leaves a hierarchy that
    /// reports one.
    public func setState(_ state: HingeState?) {
        // Always recorded, even when the reading has not changed: the first update is what proves
        // this device answers about a hinge at all.
        hasReceivedUpdate = true
        guard state != self.state else { return }
        self.state = state
    }
}
