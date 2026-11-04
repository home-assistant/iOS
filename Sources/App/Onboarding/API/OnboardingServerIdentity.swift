import Shared

/// Where an onboarded server belongs among the ones the app already has, decided once `get_config`
/// has reported its instance ID.
enum OnboardingServerIdentity: Equatable {
    /// A server the app already has, updated in place under this identifier.
    case existing(Identifier<Server>)
    /// A server the app has not seen before, stored under this identifier.
    case new(Identifier<Server>)
    /// Reports the instance ID of `existing` but answers at none of its addresses, which is what a
    /// server set up from another one's backup looks like. Only the user can tell the two apart;
    /// `separateIdentifier` is what the new server is stored under when they are kept apart.
    case ambiguous(existing: Server, separateIdentifier: Identifier<Server>)

    /// The identifier the server is stored under when nobody was asked, which keeps an ambiguous
    /// server apart: that never costs the user a server.
    var storedIdentifier: Identifier<Server> {
        switch self {
        case let .existing(identifier), let .new(identifier):
            return identifier
        case let .ambiguous(_, separateIdentifier):
            return separateIdentifier
        }
    }
}
