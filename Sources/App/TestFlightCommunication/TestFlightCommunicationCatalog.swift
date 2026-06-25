import Shared

/// Catalog of messages shown exclusively to TestFlight beta testers.
///
/// Messages are displayed in order — the first unseen message for the current platform is shown.
/// Leave `messages` empty when there is nothing to communicate.
///
/// Example:
/// ```swift
/// static let messages: [TestFlightMessage] = [
///     TestFlightMessage(
///         id: .exampleMessage,
///         title: "Thanks for testing!",
///         items: [
///             WhatsNewItem(
///                 id: .whatsNewValidationIntro,
///                 title: "New in this beta",
///                 body: "Describe what you'd like testers to focus on.",
///                 icon: .sfSymbol(.testtube2)
///             ),
///         ],
///         callToAction: .init(
///             title: "Fill out the feedback survey",
///             url: URL(string: "https://forms.example.com/beta-feedback")!
///         )
///     ),
/// ]
/// ```
enum TestFlightCommunicationCatalog {
    static let messages: [TestFlightMessage] = [
        TestFlightMessage(
            id: .includeEmailWhenReporting,
            title: "Reporting an issue?",
            items: [
                WhatsNewItem(
                    id: .testFlightIncludeEmail,
                    title: "Optional, but it helps a lot",
                    body: "When you report a problem through TestFlight, it's optional but really valuable to " +
                        "include your email address or Discord handle. With it we can reach out to share " +
                        "setup instructions or ask follow-up questions — without it we have no way to get " +
                        "back to you.",
                    icon: .sfSymbol(.envelope)
                ),
            ]
        ),
    ]
}
