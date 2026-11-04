import Foundation
import Shared
import WidgetKit

struct WidgetEntitiesEntry: TimelineEntry {
    var date: Date
    var items: [MagicItem]
    var magicItemInfoProvider: MagicItemProviderProtocol
    var entitiesState: [MagicItem: WidgetEntityState]
    var showLastUpdateTime: Bool
    var serverName: String?
}
