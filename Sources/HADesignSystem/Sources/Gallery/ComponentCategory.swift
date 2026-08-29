#if !os(watchOS)
import Foundation

/// How ``ComponentsLibraryView`` groups its components.
///
/// Frontend counterpart: the sections of the frontend's `gallery/` package. Gallery scaffolding, not
/// a component — these categories are ours, since the native set is not the web set.
public enum ComponentCategory: String, CaseIterable, Identifiable {
    case buttons
    case controls
    case inputs
    case containers
    case indicators
    case feedback
    case dataDisplay

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .buttons: "Buttons"
        case .controls: "Controls"
        case .inputs: "Inputs"
        case .containers: "Containers"
        case .indicators: "Indicators"
        case .feedback: "Feedback"
        case .dataDisplay: "Data display"
        }
    }
}
#endif
