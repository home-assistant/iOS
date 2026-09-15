import HAWatchComplications
import SwiftUI
import UIKit

/// An icon bitmap with a color baked into its pixels, drawn the way a complication whose icon color
/// the user picked draws it. Mirrors the watch's payload, which carries an already-colored raster —
/// under the old template rendering this disc came out white.
func customColoredComplicationIcon() -> Image {
    let size = CGSize(width: 24, height: 24)
    UIGraphicsBeginImageContextWithOptions(size, false, 2)
    defer { UIGraphicsEndImageContext() }
    UIColor(red: 0.6, green: 0.3, blue: 0.9, alpha: 1).setFill()
    UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
    let baked = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    return ComplicationIconRendering.image(baked, usesCustomColor: true)
}
