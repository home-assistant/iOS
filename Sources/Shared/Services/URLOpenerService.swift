import Foundation
import UIKit

public protocol URLOpenerServiceProtocol {
    @discardableResult
    func open(
        _ url: URL,
        options: [UIApplication.OpenExternalURLOptionsKey: Any],
        completionHandler: ((Bool) -> Void)?
    ) -> Bool
    
    func canOpenURL(_ url: URL) -> Bool
}

public final class URLOpenerServiceImpl: URLOpenerServiceProtocol {
    public init() {}
    
    @discardableResult
    public func open(
        _ url: URL,
        options: [UIApplication.OpenExternalURLOptionsKey: Any],
        completionHandler: ((Bool) -> Void)?
    ) -> Bool {
        #if os(iOS)
        UIApplication.shared.open(url, options: options, completionHandler: completionHandler)
        return true
        #else
        completionHandler?(false)
        return false
        #endif
    }
    
    public func canOpenURL(_ url: URL) -> Bool {
        #if os(iOS)
        return UIApplication.shared.canOpenURL(url)
        #else
        return false
        #endif
    }
}
