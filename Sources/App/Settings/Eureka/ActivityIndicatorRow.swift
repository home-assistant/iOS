import Eureka
import Foundation
import Shared

public enum ActivityIndicatorPosition: Equatable {
    case leading, trailing, center
}

public class ActivityIndicatorCell: Cell<String>, CellType {
    public let activityIndicator = with(UIActivityIndicatorView()) {
        if #available(iOS 13, *) {
            $0.style = .medium
        } else {
            $0.style = .gray
        }
    }

    private var constraintsForPosition = [ActivityIndicatorPosition: [NSLayoutConstraint]]()

    override public func setup() {
        super.setup()
        selectionStyle = .none

        height = { UITableView.automaticDimension }

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(activityIndicator)
        activityIndicator.startAnimating()

        let margins = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            activityIndicator.topAnchor.constraint(equalTo: margins.topAnchor),
            activityIndicator.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
        ])

        constraintsForPosition[.leading] = [
            activityIndicator.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            activityIndicator.trailingAnchor.constraint(lessThanOrEqualTo: margins.trailingAnchor),
        ]
        constraintsForPosition[.center] = [
            activityIndicator.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
            activityIndicator.leadingAnchor.constraint(greaterThanOrEqualTo: margins.leadingAnchor),
            activityIndicator.trailingAnchor.constraint(lessThanOrEqualTo: margins.trailingAnchor),
        ]
        constraintsForPosition[.trailing] = [
            activityIndicator.leadingAnchor.constraint(greaterThanOrEqualTo: margins.leadingAnchor),
            activityIndicator.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
        ]
    }

    override public func update() {
        super.update()

        for (key, value) in constraintsForPosition {
            if key == (row as? ActivityIndicatorRow)?.position ?? .leading {
                NSLayoutConstraint.activate(value)
            } else {
                NSLayoutConstraint.deactivate(value)
            }
        }
    }
}

public final class ActivityIndicatorRow: Row<ActivityIndicatorCell>, RowType {
    public var position: ActivityIndicatorPosition = .leading

    public required init(tag: String?) {
        super.init(tag: tag)
        cellStyle = .default
    }
}
