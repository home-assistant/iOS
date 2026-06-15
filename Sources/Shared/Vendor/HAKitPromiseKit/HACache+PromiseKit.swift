// Vendored from HAKit (Extensions/PromiseKit) — MIT licensed, home-assistant/HAKit 0.4.14.
// The HAKit SPM manifest does not export the PromiseKit integration as a product,
// so the macOS target (which consumes HAKit via SPM, not CocoaPods) vendors these
// public-API-only extension files. Member of Shared-macOS ONLY — on iOS the
// identical code ships inside the HAKit pod (HAKit/PromiseKit subspec).

import HAKit
import PromiseKit

public extension HACache {
    /// Wrap a once subscription in a Guarantee
    ///
    /// - SeeAlso: `HACache.once(_:)`
    /// - Returns: The promies for the value, and a block to cancel
    func once() -> (promise: Guarantee<ValueType>, cancel: () -> Void) {
        let (guarantee, seal) = Guarantee<ValueType>.pending()
        let token = once(seal)
        return (promise: guarantee, cancel: token.cancel)
    }
}
