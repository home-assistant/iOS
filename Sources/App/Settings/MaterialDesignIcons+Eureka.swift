import Eureka
import Shared

extension MaterialDesignIcons: SearchItem {
    public func matchesSearchQuery(_ query: String) -> Bool {
        name.matchesSearchQuery(query)
    }
}
