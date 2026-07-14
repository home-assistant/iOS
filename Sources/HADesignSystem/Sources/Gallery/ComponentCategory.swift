#if !os(watchOS)
import Foundation

public enum ComponentCategory: String, CaseIterable, Identifiable {
    case buttons
    case controls
    case inputs
    case containers
    case indicators

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .buttons: "Buttons"
        case .controls: "Controls"
        case .inputs: "Inputs"
        case .containers: "Containers"
        case .indicators: "Indicators"
        }
    }
}
#endif
