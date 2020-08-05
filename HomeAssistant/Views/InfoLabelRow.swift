import Foundation
import Eureka

final class InfoLabelRow: _LabelRow, RowType {
    enum DisplayType {
        case primary
        case secondary

        var textColor: UIColor {
            switch self {
            case .primary:
                if #available(iOS 13, *) {
                    return .label
                } else {
                    return .black
                }
            case .secondary:
                if #available(iOS 13, *) {
                    return .secondaryLabel
                } else {
                    return .gray
                }
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
