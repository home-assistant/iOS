import Foundation

/// Whether something is shown, decided from the current states rather than from the generated
/// config. The home strategy only ever builds one shape of condition — "any of these entities is
/// on", and its negation — so that is what this is, rather than a general condition tree.
public enum HomeStateCondition: Equatable, Hashable, Sendable {
    /// True when at least one of the entities is `on`.
    case anyOn([String])
    /// True when none of them is.
    case noneOn([String])

    public func isSatisfied(in registry: HomeRegistry) -> Bool {
        switch self {
        case let .anyOn(entityIds):
            entityIds.contains { registry.state($0)?.state == "on" }
        case let .noneOn(entityIds):
            !entityIds.contains { registry.state($0)?.state == "on" }
        }
    }
}
