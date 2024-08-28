import Eureka
import Shared

public final class SettingsButtonRow: _ButtonRowOf<String>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)
    }

    var isDestructive = false
    var icon: MaterialDesignIcons?
    var image: UIImage?
    var accessoryIcon: MaterialDesignIcons?
    var isAvailableForMac = true

    override public func updateCell() {
        super.updateCell()

        cell.textLabel?.textAlignment = .natural

        if isDestructive {
            cell.tintColor = .systemRed
            cell.textLabel?.textColor = .systemRed
        } else {
            cell.tintColor = nil
            cell.textLabel?.textColor = .label
        }

        if let icon, !isDestructive {
            cell.imageView?.image = icon.settingsIcon(for: cell.traitCollection)
        } else if let image {
            cell.imageView?.image = image.scaledToSize(.init(width: 24, height: 24))
                .withTintColor(AppConstants.darkerTintColor)
        } else {
            cell.imageView?.image = nil
        }

        if let accessoryIcon {
            let imageView = cell.accessoryView as? UIImageView ?? UIImageView()
            let color: UIColor

            color = .systemGray2

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
