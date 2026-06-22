import Shared

/// Catalog of the native "What's New" release that can be shown after an app update.
///
/// Set `release` to a `WhatsNewRelease` when the current app version should present release notes for a
/// matching platform. Leave it `nil` when there is no native update summary to show.
///
/// Example:
/// ```swift
/// static let release: WhatsNewRelease? = WhatsNewRelease(
///     version: WhatsNewAppVersion(major: 2026, minor: 6, patch: 0),
///     targetPlatforms: [.iPhone, .iPad],
///     items: [
///         WhatsNewItem(
///             id: .whatsNewValidationIntro,
///             title: "What's New is here",
///             body: "Describe the user-visible change.",
///             icon: .sfSymbol(.sparkles)
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
