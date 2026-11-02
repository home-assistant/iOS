#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

/// Where the Live Activity push-to-start token is kept between launches.
///
/// The app uses `.keychain`: the token is higher-value than a per-activity token (it can start any
/// new activity), so UserDefaults is intentionally avoided. Tests hand `LiveActivityRegistry` an
/// in-memory store, because the unit test host has no Keychain entitlement.
@available(iOS 17.2, *)
public struct LiveActivityPushToStartTokenStore: Sendable {
    public let read: @Sendable () -> String?
    public let write: @Sendable (String?) -> Void

    public init(read: @escaping @Sendable () -> String?, write: @escaping @Sendable (String?) -> Void) {
        self.read = read
        self.write = write
    }

    public static let keychain = LiveActivityPushToStartTokenStore(
        read: { AppConstants.Keychain[LiveActivityRegistry.pushToStartTokenKeychainKey] },
        write: { AppConstants.Keychain[LiveActivityRegistry.pushToStartTokenKeychainKey] = $0 }
    )
}
#endif
