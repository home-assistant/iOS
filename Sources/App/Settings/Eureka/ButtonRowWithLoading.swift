import Eureka
import UIKit

public final class ButtonRowWithLoading: _ButtonRowOf<Bool>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)
    }

    let activityIndicator: UIActivityIndicatorView = .init(style: .medium)

    override public func updateCell() {
        super.updateCell()

        if value == true {
            cell.accessoryView = activityIndicator
            activityIndicator.startAnimating()
        } else {
            cell.accessoryView = nil
            cell.accessoryType = .none
        }

        cell.textLabel?.textAlignment = .natural
    }
}
