import CoreGraphics
import UIKit

/// The box the vendored paths are drawn in, the same one a Material Design glyph uses.
private let viewBoxSide: CGFloat = 24

public extension BrandIcon {
    /// Renders the logo like `IconDrawable` renders a glyph, so the two are interchangeable at a
    /// call site.
    func image(ofSize size: CGSize, color: UIColor?) -> UIImage {
        let side = min(size.width, size.height)
        guard side > 0, let path = SVGPath.cgPath(from: pathData) else { return UIImage() }

        var transform = CGAffineTransform(scaleX: side / viewBoxSide, y: side / viewBoxSide)
        guard let scaled = path.copy(using: &transform) else { return UIImage() }

        UIGraphicsBeginImageContextWithOptions(CGSize(width: side, height: side), false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return UIImage() }

        context.addPath(scaled)
        context.setFillColor((color ?? .black).cgColor)
        context.fillPath(using: .winding)
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
}
