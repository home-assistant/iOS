import Foundation
import WebKit

public protocol WebsiteDataStoreHandlerProtocol {
    func cleanCache(completion: (() -> Void)?)
}

final class WebsiteDataStoreHandler: WebsiteDataStoreHandlerProtocol {
    public func cleanCache(completion: (() -> Void)? = nil) {
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date(timeIntervalSince1970: 0),
            completionHandler: {
                Current.Log.verbose("Cleaned browser cache")
                completion?()
            }
        )
    }
}

public enum WebsiteDataStoreHandlerImpl {
    static func build() -> WebsiteDataStoreHandlerProtocol {
        WebsiteDataStoreHandler()
    }
}
