import Foundation

/// The include/exclude domain rules a widget configuration carries, applied to the entities the
/// widget would otherwise display.
///
/// The two lists are independent and both optional: an empty include list means "every domain", and
/// the exclude list is applied on top of whatever the include list let through, so an entity has to
/// survive both. Domains are compared by their raw identifier rather than by ``Domain``, so an
/// entity whose domain the app does not model yet still behaves predictably — a non-empty include
/// list drops it, and an exclude list that does not name it keeps it.
public struct WidgetDomainFilter: Equatable {
    private let includedDomains: Set<String>
    private let excludedDomains: Set<String>

    public init(includedDomains: [String] = [], excludedDomains: [String] = []) {
        self.includedDomains = Set(includedDomains)
        self.excludedDomains = Set(excludedDomains)
    }

    /// True when the filter lets every entity through, which is the default configuration.
    public var isEmpty: Bool {
        includedDomains.isEmpty && excludedDomains.isEmpty
    }

    private func includes(entityId: String) -> Bool {
        let domain = entityId.components(separatedBy: ".").first ?? ""
        if !includedDomains.isEmpty, !includedDomains.contains(domain) {
            return false
        }
        return !excludedDomains.contains(domain)
    }

    public func filter(entityIds: [String]) -> [String] {
        guard !isEmpty else { return entityIds }
        return entityIds.filter { includes(entityId: $0) }
    }
}
