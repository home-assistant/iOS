import Foundation

/// Item types that can be added to the Apple Watch home configuration (or one of its folders) from
/// the iPhone configuration screens. Mirrors `CarPlayAddItemDestination`: the add menu picks one,
/// and it drives the sheet that opens the matching picker.
enum WatchAddItemDestination: String, Identifiable {
    case entity
    case area
    case complication
    case assist
    /// Created in a dedicated editor (pipeline + title + prompt) rather than picked from a list, so
    /// it has no `MagicItemAddView` picker of its own.
    case assistPrompt

    var id: String { rawValue }

    var magicItemType: MagicItemAddType? {
        switch self {
        case .entity:
            return .entities
        case .area:
            return .areas
        case .complication:
            return .complications
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
        case .area:
            return .areas
        case .complication:
            return .complications
        case .assist:
            return .assistPipelines
        case .assistPrompt:
            return nil
        }
    }
}
