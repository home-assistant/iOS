import UIKit

@IBDesignable class PermissionButton: UIButton {
    var style: Style = .default {
        didSet {
            setTitleColorForTwoState(style.textColor)
            setTitle(style.title, for: .normal)

            backgroundColor = style.backgroundColor
            contentEdgeInsets = style.insets(titleLabel?.text?.count)

            sizeToFit()
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

    func sharedInit() {
        style = .default
        titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        layer.masksToBounds = true
        layer.cornerRadius = frame.height / 2
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

        func insets(_ characterCount: Int?) -> UIEdgeInsets {
            if self == .default, characterCount ?? 5 < 4 {
                return UIEdgeInsets(top: 6, left: 22, bottom: 6, right: 22)
            }
            return UIEdgeInsets(top: 6, left: 15, bottom: 6, right: 15)
        }

        var title: String {
            switch self {
            case .default:
                return "Allow"
            case .allowed:
                return "Allowed"
            }
        }
    }
}
