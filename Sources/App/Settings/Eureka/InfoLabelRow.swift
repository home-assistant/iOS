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
                if #available(iOS 13, *) {
                    return .systemRed
                } else {
                    return .red
                }
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
