import UIKit

public extension UIImage {
    convenience init(size: CGSize, color: UIColor) {
        // why is UIGraphicsImageRenderer not available on watchOS?
        var alpha: CGFloat = 1
        color.getRed(nil, green: nil, blue: nil, alpha: &alpha)

        UIGraphicsBeginImageContextWithOptions(size, alpha == 1.0, 0)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        self.init(cgImage: image.cgImage!, scale: image.scale, orientation: image.imageOrientation)
    }
}

public extension MaterialDesignIcons {
    convenience init(serversideValueNamed value: String, fallback: MaterialDesignIcons? = nil) {
        if let fallback {
            self.init(named: value.normalizingIconString, fallback: fallback)
        } else {
            self.init(named: value.normalizingIconString)
        }
    }
}

/// The prefixes the frontend answers with a Material Design icon; `MDI_PREFIXES` in its
/// `data/iconsets.ts`.
private let materialDesignIconPrefixes = ["mdi:", "hass:", "hassio:", "hademo:"]

public extension String {
    var normalizingIconString: String {
        let named = materialDesignIconPrefixes
            .first(where: { hasPrefix($0) })
            .map { String(dropFirst($0.count)) } ?? self
        let base = named
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        return MDIMigration.migrate(icon: base)
    }
}
