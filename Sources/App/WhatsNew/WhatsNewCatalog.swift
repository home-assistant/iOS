import Shared

/// Catalog of the native "What's New" release that can be shown after an app update.
///
/// Set `release` to a `WhatsNewRelease` when the current app version should present release notes for a
/// matching platform. Leave it `nil` when there is no native update summary to show.
///
/// The `id` is the stable identity used for seen-state tracking — the release is shown at most once per `id`,
/// regardless of later changes to its platforms, version, or OS requirements. Pass an optional `title` to
/// override the default localized screen header, and give an item a `destination` to make it tappable. A
/// `.link(url)` destination pushes an in-app Safari view; a `.article(...)` destination pushes a native
/// screen with a header icon, title, Markdown body, and an optional action button.
///
/// Example:
/// ```swift
/// static let release: WhatsNewRelease? = WhatsNewRelease(
///     id: WhatsNewReleaseId("big-changes-2026.6"),
///     version: WhatsNewAppVersion(major: 2026, minor: 6, patch: 0),
///     targetPlatforms: [.iPhone, .iPad],
///     title: "Big changes in 2026.6",
///     items: [
///         WhatsNewItem(
///             id: "blog-link",
///             title: "What's New is here",
///             body: "Describe the user-visible change. Tap to read more.",
///             icon: .sfSymbol(.sparkles),
///             destination: .link(URL(string: "https://www.home-assistant.io/blog/")!)
///         ),
///         WhatsNewItem(
///             id: "support-article",
///             title: "We're dropping support for older systems",
///             body: "Tap to learn what this means for you.",
///             icon: .sfSymbol(.iphoneSlash),
///             destination: .article(ArticleMessage(
///                 icon: .sfSymbol(.iphoneSlash),
///                 title: "Support changes",
///                 body: "A longer **Markdown** explanation of the change.",
///                 action: .init(title: "Read the full announcement", url: URL(string:
/// "https://www.home-assistant.io/blog/")!)
///             ))
///         ),
///     ]
/// )
/// ```
///
/// A release is shown only when its `id` is unseen, the current platform is targeted, the OS version is
/// within `osRequirements`, and the app `version` matches. Use `osRequirements` to limit the release to the
/// OS versions where its features exist — for example a feature that only ships on iOS 26+ / macOS 15+:
/// ```swift
/// static let release: WhatsNewRelease? = WhatsNewRelease(
///     id: WhatsNewReleaseId("liquid-glass-2026.6"),
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
    static let release: WhatsNewRelease? = WhatsNewRelease(
        id: WhatsNewReleaseId("drop-support-2026.6.1"),
        version: WhatsNewAppVersion(major: 2026, minor: 6, patch: 1),
        targetPlatforms: [.iPhone, .iPad, .mac],
        osRequirements: WhatsNewOSRequirements(
            iOS: WhatsNewOSVersionRange(
                minimum: WhatsNewOSVersion(major: 15),
                maximum: .init(major: 15, minor: 9, patch: 9)
            ),
            macOS: WhatsNewOSVersionRange(
                minimum: WhatsNewOSVersion(major: 10),
                maximum: .init(major: 11, minor: 9, patch: 9)
            )
        ),
        title: L10n.WhatsNew.AppSupportUpdate.title,
        items: [
            .init(
                id: "drop-support",
                title: L10n.WhatsNew.AppSupportUpdate.itemTitle,
                body: L10n.WhatsNew.AppSupportUpdate.itemBody,
                icon: .sfSymbol(.iphoneSlash),
                destination: .link(AppConstants.WebURLs.homeAssistant) // TODO: Update with blog post link
            ),
        ]
    )
}
