import Foundation
import UIKit

public extension MaterialDesignIcons {
    /// PNG data for the icon a server-side value names, sized for an App Intents
    /// `DisplayRepresentation.Image`, or nil when the value doesn't name a known icon.
    ///
    /// The same icons recur constantly across an action or entity list, and resolving plus rendering
    /// each one is expensive (two linear scans over ~7k icons and a graphics-context render), so
    /// results are memoized by their raw server-side value. `NSCache` rather than a dictionary
    /// because the App Intents framework may read `displayRepresentation` off the main thread, and
    /// because it evicts under the memory pressure of an extension process.
    static func pngData(forServersideValue serversideValue: String) -> Data? {
        let key = serversideValue as NSString
        if let cached = cache.object(forKey: key) {
            return cached as Data
        }

        guard let data = icon(forServersideValue: serversideValue).flatMap(pngData(for:)) else {
            return nil
        }
        cache.setObject(data as NSData, forKey: key)
        return data
    }

    private static let cache = NSCache<NSString, NSData>()

    private static func icon(forServersideValue serversideValue: String) -> MaterialDesignIcons? {
        let iconName = serversideValue.normalizingIconString
        guard MaterialDesignIcons.allCases.contains(where: { $0.name == iconName }) else {
            return nil
        }
        return MaterialDesignIcons(serversideValueNamed: serversideValue)
    }

    private static func pngData(for icon: MaterialDesignIcons) -> Data? {
        MaterialDesignIcons.register()

        let size = CGSize(width: 64, height: 64)
        let imageRect = CGRect(origin: .zero, size: size).insetBy(dx: 8, dy: 8)

        #if os(watchOS)
        // watchOS has no `UIGraphicsImageRenderer`, so the icon is drawn through the legacy
        // context API — the same fallback `UIImage(size:color:)` uses.
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        icon.image(ofSize: imageRect.size, color: .black).draw(in: imageRect)
        return UIGraphicsGetImageFromCurrentImageContext()?.pngData()
        #else
        return UIGraphicsImageRenderer(size: size).pngData { _ in
            icon
                .image(ofSize: imageRect.size, color: .black)
                .draw(in: imageRect)
        }
        #endif
    }
}
