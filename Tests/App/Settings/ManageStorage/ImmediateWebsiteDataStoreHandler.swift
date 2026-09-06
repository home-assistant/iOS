import Foundation
import Shared

/// Calls its completion straight away, unlike `MockWebsiteDataStoreHandler`, which holds it until a
/// test releases it. `ManageStorageCleaner` awaits that completion, so a held one would never return.
final class ImmediateWebsiteDataStoreHandler: WebsiteDataStoreHandlerProtocol, @unchecked Sendable {
    private(set) var lastDataTypes: Set<String>?

    func cleanCache(dataTypes: Set<String>, completion: (() -> Void)?) {
        lastDataTypes = dataTypes
        completion?()
    }

    func cleanFrontendAssetCacheIfNeeded(completion: ((Bool) -> Void)?) {
        completion?(false)
    }
}
