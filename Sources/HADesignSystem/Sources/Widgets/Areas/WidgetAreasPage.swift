#if !os(watchOS)
import Foundation

/// One page of the areas widget: as many whole sections as the family holds, and the tail of a
/// section that ran over, carrying its heading again.
public struct WidgetAreasPage: Identifiable, Hashable {
    public let id: Int
    public let sections: [WidgetAreaFloorSection]

    public init(id: Int, sections: [WidgetAreaFloorSection]) {
        self.id = id
        self.sections = sections
    }
}
#endif
