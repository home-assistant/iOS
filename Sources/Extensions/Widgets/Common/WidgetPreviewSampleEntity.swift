import Foundation
import Shared

/// One entity tile of `WidgetPreviewSample`, as rendered by the custom and commonly used entities
/// widgets: the item itself, the name/icon the info provider would resolve for it, and the state
/// the tile shows underneath.
struct WidgetPreviewSampleEntity {
    let magicItem: MagicItem
    let info: MagicItem.Info
    let state: WidgetEntityState
}
