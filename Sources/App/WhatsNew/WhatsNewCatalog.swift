import Shared

/// Catalog of native "What's New" releases that can be shown after an app update.
///
/// Add a `WhatsNewRelease` when a specific app version should present release notes for a matching platform.
/// Leave `releases` empty when there is no native update summary to show.
///
/// Example:
/// ```swift
/// static let releases: [WhatsNewRelease] = [
///     WhatsNewRelease(
///         version: WhatsNewAppVersion(major: 2026, minor: 6, patch: 0),
///         targetPlatforms: [.iPhone, .iPad],
///         items: [
///             WhatsNewItem(
///                 id: .whatsNewValidationIntro,
///                 title: "What's New is here",
///                 body: "Describe the user-visible change.",
///                 icon: .sfSymbol(.sparkles)
///             ),
///         ]
///     ),
/// ]
/// ```
enum WhatsNewCatalog {
    static let releases: [WhatsNewRelease] = []
}
