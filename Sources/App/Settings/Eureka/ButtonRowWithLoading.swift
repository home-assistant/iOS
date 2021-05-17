import Eureka

public final class ButtonRowWithLoading: _ButtonRowOf<Bool>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)
    }

    let activityIndicator: UIActivityIndicatorView = {
        if #available(iOS 13, *) {
            return UIActivityIndicatorView(style: .medium)
        } else {
            return UIActivityIndicatorView(style: .gray)
        }
    }()

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
