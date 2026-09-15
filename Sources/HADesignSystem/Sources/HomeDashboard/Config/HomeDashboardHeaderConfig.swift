import Foundation

/// The greeting the overview puts above its sections. The frontend renders it as a text-only
/// markdown card with the user's name templated in; there is nothing else it can be, so this carries
/// the name rather than the markdown.
public struct HomeDashboardHeaderConfig: Equatable, Sendable {
    /// The person to greet, when the server knows who is looking.
    public let userName: String?

    public init(userName: String?) {
        self.userName = userName
    }
}
