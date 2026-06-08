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
    static let messages: [TestFlightMessage] = []
}
