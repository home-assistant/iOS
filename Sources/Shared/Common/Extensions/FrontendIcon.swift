import UIKit

/// An icon name the server sent, resolved the way the frontend resolves it: the few brand logos the
/// frontend bundles itself, and Material Design Icons for everything else.
public enum FrontendIcon: Hashable {
    case material(MaterialDesignIcons)
    case brand(BrandIcon)

    public init(serversideValueNamed value: String, fallback: MaterialDesignIcons) {
        if let brand = BrandIcon(rawValue: value.normalizingIconString) {
            self = .brand(brand)
        } else {
            self = .material(MaterialDesignIcons(serversideValueNamed: value, fallback: fallback))
        }
    }

    public func image(ofSize size: CGSize, color: UIColor?) -> UIImage {
        switch self {
        case let .material(icon):
            return icon.image(ofSize: size, color: color)
        case let .brand(icon):
            return icon.image(ofSize: size, color: color)
        }
    }
}
