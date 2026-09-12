import SwiftUI
import UIKit
import WidgetKit

/// Draws a complication's icon bitmap: `.template` throws the baked-in color away for the face's
/// tint, so only an icon with no color of its own gets it.
public enum ComplicationIconRendering {
    public static func templateRenderingMode(usesCustomColor: Bool) -> Image.TemplateRenderingMode {
        usesCustomColor ? .original : .template
    }

    public static func image(_ uiImage: UIImage, usesCustomColor: Bool) -> Image {
        let image = Image(uiImage: uiImage).renderingMode(templateRenderingMode(usesCustomColor: usesCustomColor))
        guard usesCustomColor else { return image }
        if #available(iOS 18.0, watchOS 11.0, *) {
            return image.widgetAccentedRenderingMode(.fullColor)
        }
        return image
    }
}
