import SwiftUI
import UIKit

struct WatchWidgetComplicationSnapshot: Codable {
    static let placeholderID = "placeholder"
    static let assistID = "default-assist"

    let id: String?
    let family: String
    let title: String
    let subtitle: String
    let inlineText: String
    let fraction: Double?
    let tint: String?
    let iconData: Data?

    static var placeholder: Self {
        .init(
            id: placeholderID,
            family: "",
            title: WatchWidgetConstants.appName,
            subtitle: WatchWidgetConstants.placeholderSubtitle,
            inlineText: WatchWidgetConstants.appName,
            fraction: nil,
            tint: nil,
            iconData: nil
        )
    }

    static var assist: Self {
        .init(
            id: assistID,
            family: "",
            title: "Assist",
            subtitle: WatchWidgetConstants.appName,
            inlineText: "Assist",
            fraction: nil,
            tint: nil,
            iconData: nil
        )
    }

    var recommendationID: String {
        id ?? [family, title, subtitle].joined(separator: ":")
    }

    var recommendationTitle: String {
        title.isEmpty ? WatchWidgetConstants.appName : title
    }

    var widgetURL: URL? {
        recommendationID == Self.assistID ? WatchWidgetConstants.DeepLink.assistURL : nil
    }

    var tintColor: Color {
        Color(hex: tint) ?? .accentColor
    }

    private var isBuiltIn: Bool {
        [Self.placeholderID, Self.assistID].contains(recommendationID)
    }

    var isAssist: Bool {
        recommendationID == Self.assistID
    }

    /// The custom icon carried by a user-configured complication. Built-in complications (placeholder /
    /// Assist) intentionally ignore any carried icon and use a clean SF Symbol instead: the Home
    /// Assistant logo is a solid, full-bleed shape that collapses into an unreadable blob when the watch
    /// renders a complication as a monochrome template, whereas an SF Symbol renders as a crisp glyph.
    var iconImage: Image? {
        guard !isBuiltIn, let iconData, let image = UIImage(data: iconData) else { return nil }
        return Image(uiImage: image).renderingMode(.template)
    }

    // Asset-catalog image used when there is no custom template icon: the Assist symbol for the Assist
    // complication, otherwise the Home Assistant logo. Both are template-rendering assets in the
    // widget bundle so they tint cleanly on the watch face.
    var fallbackImageName: String {
        switch recommendationID {
        case Self.assistID:
            WatchWidgetConstants.assistIconAssetName
        default:
            WatchWidgetConstants.logoAssetName
        }
    }
}
