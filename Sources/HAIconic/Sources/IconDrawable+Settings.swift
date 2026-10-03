#if os(macOS)
import AppKit

public extension IconDrawable {
    static var settingsIconSize: CGSize { .init(width: 24, height: 24) }

    /// The icon as a settings row draws it on the Mac, inset a little inside the row's icon box.
    func settingsIcon() -> NSImage {
        let edgeInsets = NSEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)

        // note: not using the IconDrawable insets as they don't exactly do this
        let size = Self.settingsIconSize
        return UIGraphicsImageRenderer(size: size).image { _ in
            let rect = CGRect(origin: .zero, size: size).inset(by: edgeInsets)
            image(ofSize: rect.size, color: .black).draw(in: rect)
        }.withRenderingMode(.alwaysTemplate)
    }
}

#elseif os(iOS)
import UIKit

public extension IconDrawable {
    static var settingsIconSize: CGSize { .init(width: 24, height: 24) }

    /// The icon as a settings row draws it for the current trait collection.
    func settingsIcon() -> UIImage {
        settingsIcon(for: .current)
    }

    func settingsIcon(for traitCollection: UITraitCollection) -> UIImage {
        let edgeInsets: UIEdgeInsets

        if traitCollection.userInterfaceIdiom == .mac {
            edgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
        } else {
            edgeInsets = .zero
        }

        // note: not using the IconDrawable insets as they don't exactly do this
        let size = Self.settingsIconSize
        return UIGraphicsImageRenderer(size: size).image { _ in
            let rect = CGRect(origin: .zero, size: size).inset(by: edgeInsets)
            image(ofSize: rect.size, color: .black).draw(in: rect)
        }.withRenderingMode(.alwaysTemplate)
    }
}
#endif
