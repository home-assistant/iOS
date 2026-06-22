import Shared

/// Catalog of the native "What's New" release that can be shown after an app update.
///
/// Set `release` to a `WhatsNewRelease` when the current app version should present release notes for a
/// matching platform. Leave it `nil` when there is no native update summary to show.
///
/// Pass an optional `title` to override the default localized screen header, and give an item a `link` to
/// make it tappable — the link opens in an in-app Safari view.
///
/// Example:
/// ```swift
/// static let release: WhatsNewRelease? = WhatsNewRelease(
///     version: WhatsNewAppVersion(major: 2026, minor: 6, patch: 0),
///     targetPlatforms: [.iPhone, .iPad],
///     title: "Big changes in 2026.6",
///     items: [
///         WhatsNewItem(
///             id: .whatsNewValidationIntro,
///             title: "What's New is here",
///             body: "Describe the user-visible change. Tap to read more.",
///             icon: .sfSymbol(.sparkles),
///             link: URL(string: "https://www.home-assistant.io/blog/")
///         ),
///     ]
/// )
/// ```
///
/// Use `osRequirements` to limit the release to the OS versions where its features exist — for example a
/// feature that only ships on iOS 26 and later, or macOS 15 and later:
/// ```swift
/// static let release: WhatsNewRelease? = WhatsNewRelease(
///     version: WhatsNewAppVersion(major: 2026, minor: 6, patch: 0),
///     targetPlatforms: [.iPhone, .iPad, .mac],
///     osRequirements: WhatsNewOSRequirements(
///         iOS: WhatsNewOSVersionRange(minimum: WhatsNewOSVersion(major: 26)),
///         macOS: WhatsNewOSVersionRange(minimum: WhatsNewOSVersion(major: 15))
///     ),
///     items: [...]
/// )
/// ```
enum WhatsNewCatalog {
    static let release: WhatsNewRelease? = nil
}
