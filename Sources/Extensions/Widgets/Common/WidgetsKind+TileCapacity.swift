import Foundation
import Shared

extension WidgetsKind {
    /// How full the family gets packed with tiles.
    ///
    /// Widgets people fill themselves pack the family. The commonly-used widget is the exception:
    /// it picks its own contents, so it stops at the count that still draws as entity tiles rather
    /// than filling the family with a compressed grid nobody chose.
    var tileCapacity: WidgetTileCapacity {
        self == .commonlyUsedEntities ? .tile : .packed
    }
}
