import Foundation
import WidgetKit

enum WatchWidgetConstants {
    static let appName = "Home Assistant"
    static let defaultBundleID = "io.robbie.HomeAssistant.watchkitapp.WatchWidgets"
    static let defaultsKey = "watchWidgetComplicationSnapshots"
    static let logoAssetName = "Logo"
    static let assistIconAssetName = "message-processing-outline"
    static let placeholderSubtitle = "Complication"
    static let timelineRefreshInterval: TimeInterval = 15 * 60

    enum DeepLink {
        static let releaseScheme = "homeassistant"
        static let debugScheme = "homeassistant-dev"
        static let assistHost = "assist"

        static var scheme: String {
            appBundleID.contains(".dev") ? debugScheme : releaseScheme
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
        static let circularIconGaugePadding: CGFloat = 8
        static let assistIconPadding: CGFloat = 8
        static let rectangularLogoSize: CGFloat = 18
        static let rectangularSpacing: CGFloat = 6
        static let rectangularTextSpacing: CGFloat = 1
    }
}
