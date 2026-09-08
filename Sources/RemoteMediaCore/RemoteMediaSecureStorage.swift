import Foundation

/// Where the RemoteMedia transport context's bytes live.
///
/// A seam over the Keychain, so the store's behaviour can be tested without a signed host: the unit
/// test bundle carries no `keychain-access-groups` entitlement and every `SecItem` call there fails
/// with `errSecMissingEntitlement`.
public protocol RemoteMediaSecureStorage: Sendable {
    func data() -> Data?
    func save(_ data: Data) throws
    func clear()
}
