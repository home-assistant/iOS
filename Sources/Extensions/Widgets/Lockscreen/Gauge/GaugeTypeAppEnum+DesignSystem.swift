import Foundation
import Shared

@available(iOS 17, *)
extension GaugeTypeAppEnum {
    /// The design system's own gauge shapes, which is what its gauge components are built around.
    var designSystemType: WidgetGaugeType {
        switch self {
        case .normal: .normal
        case .singleLabel: .singleLabel
        case .capacity: .capacity
        }
    }
}
