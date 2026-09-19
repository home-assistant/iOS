import Foundation

/// Localized copy for the widget extension. The extension bundle carries no strings tables, so keys
/// are resolved against the containing watch app's `Localizable.strings`, which Lokalise maintains.
enum WatchWidgetStrings {
    static var assistTitle: String {
        localized("app_intents.watch_assist.title", defaultValue: "Assist")
    }

    static var assistControlDescription: String {
        localized(
            "app_intents.watch_assist.description",
            defaultValue: "Opens Assist using the pipeline configured for the watch"
        )
    }

    static var energyTitle: String {
        localized("widgets.energy.title", defaultValue: "Energy")
    }

    static var energyDescription: String {
        localized("widgets.energy.description", defaultValue: "Show your energy dashboard at a glance.")
    }

    /// Shown when the app group holds no energy payload at all — the watch app has never had the
    /// chance to read one, rather than having read one and found nothing in it.
    static var energyNoData: String {
        localized("widgets.energy.no_data", defaultValue: "No energy data")
    }

    private static let containingAppBundle: Bundle = {
        let appURL = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        return Bundle(url: appURL) ?? .main
    }()

    private static func localized(_ key: String, defaultValue: String) -> String {
        containingAppBundle.localizedString(forKey: key, value: defaultValue, table: nil)
    }
}
