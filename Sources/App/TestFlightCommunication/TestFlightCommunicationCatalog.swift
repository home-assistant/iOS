import Shared

/// Catalog of the message shown exclusively to TestFlight beta testers.
///
/// Set `message` when there is something to communicate to testers on a matching platform. Leave it `nil`
/// when there is nothing to communicate.
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
///     callToAction: .init(
///         title: "Fill out the feedback survey",
///         url: URL(string: "https://forms.example.com/beta-feedback")!
///     )
/// )
/// ```
enum TestFlightCommunicationCatalog {
    static let message: TestFlightMessage? = nil
}
