import Foundation
import WebKit

public protocol WebsiteDataStoreHandlerProtocol {
    func cleanCache(dataTypes: Set<String>, completion: (() -> Void)?)
    func cleanFrontendAssetCacheIfNeeded(completion: ((Bool) -> Void)?)
}

public extension WebsiteDataStoreHandlerProtocol {
    func cleanCache(completion: (() -> Void)? = nil) {
        cleanCache(dataTypes: WKWebsiteDataStore.allWebsiteDataTypes(), completion: completion)
    }
}

final class WebsiteDataStoreHandler: WebsiteDataStoreHandlerProtocol {
    /// Removes website data, the way `WKWebsiteDataStore` does.
    ///
    /// Injected because a unit test cannot wait on the real store: its completion arrives through
    /// the WebKit networking process, which does not reliably start under the test runner, and the
    /// test then hangs on the wait instead of failing on what it set out to check.
    typealias DataRemover = (
        _ dataTypes: Set<String>,
        _ modifiedSince: Date,
        _ completion: @escaping () -> Void
    ) -> Void

    private let removeData: DataRemover

    init(removeData: @escaping DataRemover = WebsiteDataStoreHandler.removeFromDefaultStore) {
        self.removeData = removeData
    }

    private static func removeFromDefaultStore(
        dataTypes: Set<String>,
        modifiedSince: Date,
        completion: @escaping () -> Void
    ) {
        WKWebsiteDataStore.default().removeData(
            ofTypes: dataTypes,
            modifiedSince: modifiedSince,
            completionHandler: completion
        )
    }

    private enum Constants {
        static let lastFrontendAssetCacheCleanDateKey = "lastFrontendAssetCacheCleanDate"
        static let lastFrontendAssetCacheCleanVersionKey = "lastFrontendAssetCacheCleanVersion"
    }

    private var lastFrontendAssetCacheCleanDate: Date? {
        get {
            Current.settingsStore.prefs.object(forKey: Constants.lastFrontendAssetCacheCleanDateKey) as? Date
        }
        set {
            Current.settingsStore.prefs.set(newValue, forKey: Constants.lastFrontendAssetCacheCleanDateKey)
        }
    }

    private var lastFrontendAssetCacheCleanVersion: String? {
        get {
            Current.settingsStore.prefs.string(forKey: Constants.lastFrontendAssetCacheCleanVersionKey)
        }
        set {
            Current.settingsStore.prefs.set(newValue, forKey: Constants.lastFrontendAssetCacheCleanVersionKey)
        }
    }

    func cleanCache(dataTypes: Set<String>, completion: (() -> Void)? = nil) {
        Self.onMainThread {
            self.removeData(dataTypes, Date(timeIntervalSince1970: 0)) {
                if dataTypes.isSuperset(of: WebsiteDataStoreHandlerImpl.frontendAssetDataTypes) {
                    self.lastFrontendAssetCacheCleanDate = Current.date()
                    self.lastFrontendAssetCacheCleanVersion = Current.clientVersion().description
                }
                Current.Log.verbose("Cleaned browser cache for data types: \(dataTypes)")
                Self.onMainThread(completion)
            }
        }
    }

    func cleanFrontendAssetCacheIfNeeded(completion: ((Bool) -> Void)? = nil) {
        guard WebsiteDataStoreHandlerImpl.shouldCleanFrontendAssetCache(
            lastCleanDate: lastFrontendAssetCacheCleanDate,
            lastCleanVersion: lastFrontendAssetCacheCleanVersion,
            currentVersion: Current.clientVersion().description,
            now: Current.date()
        ) else {
            Self.onMainThread { completion?(false) }
            return
        }

        Current.Log.info("Resetting frontend cache, it is stale or was built by another app version")
        cleanCache(dataTypes: WebsiteDataStoreHandlerImpl.frontendAssetDataTypes) {
            completion?(true)
        }
    }

    private static func onMainThread(_ block: (() -> Void)?) {
        guard let block else { return }
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}

public enum WebsiteDataStoreHandlerImpl {
    static func build() -> WebsiteDataStoreHandlerProtocol {
        WebsiteDataStoreHandler()
    }

    static let frontendAssetCacheCleanInterval: TimeInterval = 3 * 24 * 60 * 60

    static func shouldCleanFrontendAssetCache(
        lastCleanDate: Date?,
        lastCleanVersion: String?,
        currentVersion: String,
        now: Date
    ) -> Bool {
        guard let lastCleanDate else { return true }
        guard lastCleanVersion == currentVersion else { return true }
        return now.timeIntervalSince(lastCleanDate) > frontendAssetCacheCleanInterval
    }

    public static let frontendAssetDataTypes: Set<String> = [
        WKWebsiteDataTypeDiskCache,
        WKWebsiteDataTypeMemoryCache,
        WKWebsiteDataTypeFetchCache,
        WKWebsiteDataTypeServiceWorkerRegistrations,
    ]
}
