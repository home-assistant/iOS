import Shared
import UIKit

@IBDesignable class PermissionButton: UIButton {
    var style: Style = .default {
        didSet {
            setTitleColorForTwoState(style.textColor)
            setTitle(style.title, for: .normal)

            backgroundColor = style.backgroundColor
        }
    }

    init() {
        super.init(frame: .zero)
        sharedInit()
    }

    override required init(frame: CGRect) {
        super.init(frame: frame)
        sharedInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        sharedInit()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        sharedInit()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layer.cornerRadius = frame.height / 2
    }

    func sharedInit() {
        contentEdgeInsets = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)

        style = .default
        layer.masksToBounds = true

        titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.baselineAdjustment = .alignCenters
    }

    override func setTitle(_ title: String?, for state: UIControl.State) {
        super.setTitle(title?.uppercased(), for: state)
    }

    private func setTitleColorForTwoState(_ color: UIColor) {
        setTitleColor(color, for: .normal)
        setTitleColor(color.withAlphaComponent(0.7), for: .highlighted)
    }

    enum Style {
        case `default`
        case allowed

        var backgroundColor: UIColor {
            switch self {
            case .default: // Light grey - #f0f1f6
                return #colorLiteral(red: 0.941176471, green: 0.945098039, blue: 0.964705882, alpha: 1)
            case .allowed: // Blue - #0076ff
                return #colorLiteral(red: 0, green: 0.462745098, blue: 1, alpha: 1)
            }
        }

        var textColor: UIColor {
            switch self {
            case .default: // Blue - #0076ff
                return #colorLiteral(red: 0, green: 0.462745098, blue: 1, alpha: 1)
            case .allowed: // Light grey - #f0f1f6
                return #colorLiteral(red: 0.941176471, green: 0.945098039, blue: 0.964705882, alpha: 1)
            }
        }

        var title: String {
            switch self {
            case .default:
                return L10n.Onboarding.Permissions.allow
            case .allowed:
                return L10n.Onboarding.Permissions.allowed
            }
        }
    }
}
