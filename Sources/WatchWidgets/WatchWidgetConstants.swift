import Foundation
import WidgetKit

enum WatchWidgetConstants {
    static let appName = "Home Assistant"
    static let defaultBundleID = "io.robbie.HomeAssistant.watchkitapp.WatchWidgets"
    static let defaultsKey = "watchWidgetComplicationSnapshots"
    static let logoAssetName = "Logo"
    static let templateLogoAssetName = "TemplateLogo"
    static let assistIconAssetName = "message-processing-outline"
    static let placeholderSubtitle = "Complication"
    /// Neutral value shown in the complication picker's preview instead of a possibly-stale
    /// live value (see `WatchWidgetComplicationSnapshot.previewVariant`).
    static let previewValueText = "--"
    static let previewGaugeFraction: Double = 0.5
    static let timelineRefreshInterval: TimeInterval = 15 * 60

    enum DeepLink {
        static let releaseScheme = "homeassistant"
        static let debugScheme = "homeassistant-dev"
        static let assistHost = "assist"

        static var scheme: String {
            // The widget's bundle id isn't suffixed with ".dev" in debug builds, so detect the build
            // configuration at compile time rather than from the bundle id.
            #if DEBUG
            debugScheme
            #else
            releaseScheme
            #endif
        }

        static var assistURL: URL? {
            URL(string: "\(scheme)://\(assistHost)")
        }
    }

    enum Symbol {
        static let homeAssistant = "house.fill"
        static let assist = "message.fill"
    }

    static var appGroupID: String {
        "group." + appBundleID
    }

    static var appBundleID: String {
        widgetBundleID
            .replacingOccurrences(of: ".WatchWidgets", with: "")
            .replacingOccurrences(of: ".watchkitapp", with: "")
            .lowercased()
    }

    static var kind: String {
        widgetBundleID
    }

    static let supportedFamilies: [WidgetFamily] = [
        .accessoryCircular,
        .accessoryRectangular,
        .accessoryInline,
        .accessoryCorner,
    ]

    private static var widgetBundleID: String {
        Bundle.main.bundleIdentifier ?? defaultBundleID
    }

    enum Layout {
        static let logoPadding: CGFloat = 5
        static let gaugeLogoPadding: CGFloat = 6
        /// Inset for an icon shown inside a circular gauge, so it doesn't touch the ring.
        static let circularIconGaugePadding: CGFloat = 2
        static let assistIconPadding: CGFloat = 8
        static let rectangularLogoSize: CGFloat = 18
        static let rectangularSpacing: CGFloat = 6
        static let rectangularTextSpacing: CGFloat = 1
        /// Size of the icon shown inside a circular complication's center stack.
        static let circularIconSize: CGFloat = 18
        /// Vertical spacing between the circular complication's value and name. Negative to counteract
        /// the value font's tall line box, which otherwise leaves too large a gap above the name.
        static let circularCenterSpacing: CGFloat = -4
    }

    /// Font sizes and scaling for the circular complication's center content.
    enum Font {
        /// Enlarged value font used when the value is the only thing shown in a circular complication.
        static let circularValueOnlySize: CGFloat = 22
        /// Minimum scale the value shrinks to before it's clipped, so long values still fit.
        static let circularValueMinScale: CGFloat = 0.2
        /// Font size for the complication name shown beneath the value.
        static let circularNameSize: CGFloat = 9
        /// Minimum scale the name shrinks to before it's clipped.
        static let circularNameMinScale: CGFloat = 0.4
    }
}
