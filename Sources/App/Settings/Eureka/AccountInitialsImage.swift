import Shared
import UIKit

enum AccountInitialsImage {
    private static func initials(for string: String?) -> String {
        // swiftlint:disable:next line_length
        // matching https://github.com/home-assistant/frontend/blob/42bf350034b7a53f0c6ba76791ea9d2a65bf6d67/src/components/user/ha-user-badge.ts

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

    static func image(for name: String?, size: CGSize) -> UIImage {
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
                    .foregroundColor: UIColor.white
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
}
