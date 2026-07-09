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
        WKWebsiteDataStore.default().removeData(
            ofTypes: dataTypes,
            modifiedSince: Date(timeIntervalSince1970: 0),
            completionHandler: {
                Current.Log.verbose("Cleaned browser cache for data types: \(dataTypes)")
                completion?()
            }
        )
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
