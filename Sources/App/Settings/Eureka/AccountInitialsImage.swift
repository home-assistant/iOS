import Shared
import UIKit

enum AccountInitialsImage {
    private static func initials(for string: String?) -> String {
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

    static var defaultSize: CGSize {
        let height = min(64, UIFont.preferredFont(forTextStyle: .body).lineHeight * 2.0)
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

    static func addImage(size: CGSize = Self.defaultSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            let rect = CGRect(origin: .zero, size: size)

            let path = UIBezierPath(ovalIn: rect.insetBy(dx: 1.0, dy: 1.0))
            path.lineWidth = 2.0
            path.setLineDash([5, 3], count: 2, phase: 0)
            path.stroke(with: .normal, alpha: 0.4)

            let iconEdge: CGFloat = 24.0

            let image = MaterialDesignIcons.plusIcon
                .image(ofSize: CGSize(width: iconEdge, height: iconEdge), color: .black)

            let imageOrigin = CGPoint(x: rect.midX - iconEdge / 2.0, y: rect.midY - iconEdge / 2.0)
            image.draw(at: imageOrigin)
        }.withRenderingMode(.alwaysTemplate)
    }

    static func allImage(size: CGSize = Self.defaultSize) -> UIImage {
        UIImage()
    }
}
