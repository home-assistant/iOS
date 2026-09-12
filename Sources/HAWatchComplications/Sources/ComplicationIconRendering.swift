import SwiftUI
import UIKit

/// Draws a complication's icon bitmap: `.template` throws the baked-in color away for the face's
/// tint, so only an icon with no color of its own gets it.
public enum ComplicationIconRendering {
    public static func templateRenderingMode(usesCustomColor: Bool) -> Image.TemplateRenderingMode {
        usesCustomColor ? .original : .template
    }

    public static func image(_ uiImage: UIImage, usesCustomColor: Bool) -> Image {
        Image(uiImage: uiImage).renderingMode(templateRenderingMode(usesCustomColor: usesCustomColor))
    }
}
