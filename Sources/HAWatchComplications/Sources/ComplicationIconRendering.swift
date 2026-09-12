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
        var image = Image(uiImage: uiImage).renderingMode(templateRenderingMode(usesCustomColor: usesCustomColor))
        // A tinted face re-colors what it composes, which would undo `.original`.
        if #available(iOS 18.0, watchOS 11.0, *), usesCustomColor {
            image = image.widgetAccentedRenderingMode(.fullColor)
        }
        return image
    }
}
