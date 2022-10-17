import Shared
import UIKit

enum AccountInitialsImage {
    private static func initials(for string: String?) -> String {
        // matching
        // https://github.com/home-assistant/frontend/blob/42bf350034b7a53f0c6ba76791ea9d2a65bf6d67/src/components/user/ha-user-badge.ts

        guard let string = string else {
            return "?"
        }

        return string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .prefix(3)
            .compactMap { $0.first.map(String.init(_:)) }
            .joined()
    }

    static var defaultSize: CGSize {
        let height = ceil(min(64, UIFont.preferredFont(forTextStyle: .body).lineHeight * 2.0))
        return CGSize(width: height, height: height)
    }

    static func image(for name: String?, size: CGSize = Self.defaultSize) -> UIImage {
        let initials = self.initials(for: name)

        let rect = CGRect(origin: .zero, size: size)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            Constants.tintColor.setFill()
            context.fill(rect)

            let fontSize = size.height / (initials.count >= 3 ? 3 : 2)

            let initials = NSMutableAttributedString(
                string: initials,
                attributes: [
                    .font: UIFont.systemFont(ofSize: fontSize, weight: .regular),
                    .foregroundColor: UIColor.white,
                ]
            )
            let initialsSize = initials
                .boundingRect(with: size, options: .usesLineFragmentOrigin, context: nil)
                .size
            let initialsRect = rect.insetBy(
                dx: max(4, (size.width - initialsSize.width) / 2.0),
                dy: max(4, (size.height - initialsSize.height) / 2.0)
            )
            initials.draw(
                with: initialsRect,
                options: [.usesLineFragmentOrigin],
                context: nil
            )
        }
        image.accessibilityLabel = initials
        return image
    }

    static func addImage(traitCollection: UITraitCollection) -> UIImage {
        MaterialDesignIcons.plusBoxMultipleOutlineIcon.settingsIcon(for: traitCollection)
    }

    static func allImage(traitCollection: UITraitCollection) -> UIImage {
        UIImage()
    }
}
