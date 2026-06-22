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
        id: .includeEmailWhenReporting,
        title: "Reporting an issue?",
        items: [
            WhatsNewItem(
                id: "testflight-include-email",
                title: "Optional, but it helps a lot",
                body: "When you report a problem through TestFlight, it's optional but really valuable to " +
                    "include your email address or Discord handle. With it we can reach out to share " +
                    "setup instructions or ask follow-up questions — without it we have no way to get " +
                    "back to you.",
                icon: .sfSymbol(.envelope)
            ),
        ]
    )
}
