import Foundation
import WebKit

public protocol WebsiteDataStoreHandlerProtocol {
    func cleanCache(dataTypes: Set<String>, completion: (() -> Void)?)
}

public extension WebsiteDataStoreHandlerProtocol {
    func cleanCache(completion: (() -> Void)? = nil) {
        cleanCache(dataTypes: WKWebsiteDataStore.allWebsiteDataTypes(), completion: completion)
    }
}

final class WebsiteDataStoreHandler: WebsiteDataStoreHandlerProtocol {
    func cleanCache(dataTypes: Set<String>, completion: (() -> Void)? = nil) {
        Self.onMainThread {
            WKWebsiteDataStore.default().removeData(
                ofTypes: dataTypes,
                modifiedSince: Date(timeIntervalSince1970: 0),
                completionHandler: {
                    Current.Log.verbose("Cleaned browser cache for data types: \(dataTypes)")
                    Self.onMainThread(completion)
                }
            )
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

    public static let frontendAssetDataTypes: Set<String> = [
        WKWebsiteDataTypeDiskCache,
        WKWebsiteDataTypeMemoryCache,
        WKWebsiteDataTypeFetchCache,
        WKWebsiteDataTypeServiceWorkerRegistrations,
    ]
}
