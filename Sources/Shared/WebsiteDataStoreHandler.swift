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
    /// Clears `dataTypes` from the website data store and calls back once it has. WebKit's own store by
    /// default; a test hands in its own, since the real one can take longer to answer than a test waits.
    typealias RemoveData = (_ dataTypes: Set<String>, _ completion: @escaping () -> Void) -> Void

    private enum Constants {
        static let lastFrontendAssetCacheCleanDateKey = "lastFrontendAssetCacheCleanDate"
        static let lastFrontendAssetCacheCleanVersionKey = "lastFrontendAssetCacheCleanVersion"
    }

    private let removeData: RemoveData

    init(removeData: @escaping RemoveData = WebsiteDataStoreHandler.removeWebsiteData) {
        self.removeData = removeData
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
            self.removeData(dataTypes) {
                if dataTypes.isSuperset(of: WebsiteDataStoreHandlerImpl.frontendAssetDataTypes) {
                    self.lastFrontendAssetCacheCleanDate = Current.date()
                    self.lastFrontendAssetCacheCleanVersion = Current.clientVersion().description
                }
                Current.Log.verbose("Cleaned browser cache for data types: \(dataTypes)")
                Self.onMainThread(completion)
            }
        }
    }

    static func removeWebsiteData(dataTypes: Set<String>, completion: @escaping () -> Void) {
        WKWebsiteDataStore.default().removeData(
            ofTypes: dataTypes,
            modifiedSince: Date(timeIntervalSince1970: 0),
            completionHandler: completion
        )
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
