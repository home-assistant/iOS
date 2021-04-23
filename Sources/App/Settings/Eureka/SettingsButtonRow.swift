import Eureka
import Shared

public final class SettingsButtonRow: _ButtonRowOf<String>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)
    }

    var isDestructive = false
    var icon: MaterialDesignIcons?
    var accessoryIcon: MaterialDesignIcons?

    override public func updateCell() {
        super.updateCell()

        cell.textLabel?.textAlignment = .natural

        if #available(iOS 13, *) {
            if isDestructive {
                cell.tintColor = .systemRed
                cell.textLabel?.textColor = .systemRed
            } else {
                cell.tintColor = nil
                cell.textLabel?.textColor = .label
            }
        } else {
            if isDestructive {
                cell.tintColor = .red
                cell.textLabel?.textColor = .red
            } else {
                cell.tintColor = nil
                cell.textLabel?.textColor = .black
            }
        }

        if let icon = icon, !isDestructive {
            cell.imageView?.image = icon.settingsIcon(for: cell.traitCollection)
        } else {
            cell.imageView?.image = nil
        }

        if let accessoryIcon = accessoryIcon {
            let imageView = cell.accessoryView as? UIImageView ?? UIImageView()
            let color: UIColor

            if #available(iOS 13, *) {
                color = .systemGray2
            } else {
                color = .lightGray
            }

            let iconSize = MaterialDesignIcons.settingsIconSize

            imageView.image = accessoryIcon
                .image(ofSize: CGSize(width: iconSize.width * 0.85, height: iconSize.height * 0.85), color: color)
                .withRenderingMode(.alwaysOriginal)
            imageView.sizeToFit()
            cell.accessoryView = imageView
        } else if isDestructive {
            cell.accessoryType = .none
        } else {
            cell.accessoryType = .disclosureIndicator
        }
    }
}
