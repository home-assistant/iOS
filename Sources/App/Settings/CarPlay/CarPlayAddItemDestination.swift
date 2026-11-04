import Foundation
import Shared

/// Item types that can be added to CarPlay Quick Access (or a Quick Access folder) from the
/// iPhone configuration screens.
enum CarPlayAddItemDestination: String, Identifiable {
    case entity
    case assist
    case assistPrompt

    var id: String { rawValue }

    var magicItemType: MagicItemAddType? {
        switch self {
        case .entity:
            return .entities
        case .assist:
            return .assistPipelines
        case .assistPrompt:
            return nil
        }
    }

    var pickerOption: MagicItemAddView.PickerOption? {
        switch self {
        case .entity:
            return .entities
        case .assist:
            return .assistPipelines
        case .assistPrompt:
            return nil
        }
    }
}
