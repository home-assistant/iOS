import Foundation

/// How Home Assistant classifies an entity that is not a primary control: the `entity_category` the
/// registry carries. The home dashboard shows primary entities only, which it expresses as a filter
/// on ``HomeEntityCategory/none``.
public enum HomeEntityCategory: String, Equatable, Hashable, Sendable, CaseIterable {
    /// An entity that configures its device rather than being part of it.
    case config
    /// An entity that reports on its device's health.
    case diagnostic
}
