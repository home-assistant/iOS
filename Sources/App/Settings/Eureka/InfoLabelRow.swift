import Eureka
import Foundation

final class InfoLabelRow: _LabelRow, RowType {
    enum DisplayType {
        case primary
        case secondary
        case important

        var textColor: UIColor {
            switch self {
            case .important:
                return .systemRed
            case .primary:
                return .label
            case .secondary:
                return .secondaryLabel
            }
        }
    }

    var displayType: DisplayType = .secondary

    override func updateCell() {
        super.updateCell()

        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.textColor = displayType.textColor
    }
}
