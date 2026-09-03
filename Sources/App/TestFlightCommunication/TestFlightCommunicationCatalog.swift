import Shared

/// Catalog of the message shown exclusively to TestFlight beta testers.
///
/// Set `message` when there is something to communicate to testers on a matching platform. Leave it `nil`
/// when there is nothing to communicate.
///
/// The message is shown only when its `id` is unseen and the current environment matches: the current
/// platform must be in `targetPlatforms`, and — when supplied — the app `version` must match exactly and the
/// OS version must fall within `osRequirements`. Leave `version` / `osRequirements` unset to target every
/// build and OS version of the matching platforms.
///
/// Example:
/// ```swift
/// static let message: TestFlightMessage? = TestFlightMessage(
///     id: .exampleMessage,
///     title: "Thanks for testing!",
///     items: [
///         WhatsNewItem(
///             id: .whatsNewValidationIntro,
///             title: "New in this beta",
///             body: "Describe what you'd like testers to focus on.",
///             icon: .sfSymbol(.testtube2)
///         ),
///     ],
///     osRequirements: WhatsNewOSRequirements(
///         iOS: WhatsNewOSVersionRange(minimum: WhatsNewOSVersion(major: 26))
///     ),
///     callToAction: .init(
///         title: "Fill out the feedback survey",
///         url: URL(string: "https://forms.example.com/beta-feedback")!
///     )
/// )
/// ```
enum TestFlightCommunicationCatalog {
    static let message: TestFlightMessage? = TestFlightMessage(
        id: .releaseNotes,
        title: "What's new in the 2026.9.1 beta",
        items: [
            WhatsNewItem(
                id: "widgets",
                title: "Widgets",
                body: "New Entities widget, with tap behavior and filtering that match the frontend.",
                icon: .sfSymbol(.squareGrid2x2Fill)
            ),
            WhatsNewItem(
                id: "app-labs",
                title: "App Labs",
                body: "Try out experimental features from Settings.",
                icon: .sfSymbol(.testtube2)
            ),
            WhatsNewItem(
                id: "sensors",
                title: "Sensors are opt-in",
                body: "Every sensor is listed and only reports once you switch it on.",
                icon: .sfSymbol(.antennaRadiowavesLeftAndRight)
            ),
            WhatsNewItem(
                id: "watch",
                title: "Apple Watch",
                body: "Registers as its own device and reports its own battery.",
                icon: .sfSymbol(.applewatch)
            ),
            WhatsNewItem(
                id: "fixes",
                title: "Fixes",
                body: "Mac sidebar, add-on panels, missing icons and watch complications.",
                icon: .sfSymbol(.checkmarkCircleFill)
            ),
        ],
        version: WhatsNewAppVersion(major: 2026, minor: 9, patch: 1)
    )
}

extension TestFlightMessageId {
    static let releaseNotes = TestFlightMessageId("release-notes-2026.9.1")
}
