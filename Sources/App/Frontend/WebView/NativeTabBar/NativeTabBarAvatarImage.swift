#if os(iOS)
import Shared
import UIKit

/// The profile picture, or the user's initial on the brand colour, as a round bar button image.
enum NativeTabBarAvatarImage {
    static func circular(_ picture: UIImage?, initial: String, size: CGFloat) -> UIImage {
        let bounds = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        let image = UIGraphicsImageRenderer(bounds: bounds).image { context in
            UIBezierPath(ovalIn: bounds).addClip()
            if let picture {
                picture.draw(in: aspectFillRect(for: picture.size, in: bounds))
            } else {
                UIColor.haPrimary.setFill()
                context.fill(bounds)
                let text = NSAttributedString(
                    string: initial.prefix(1).uppercased(),
                    attributes: [
                        .font: UIFont.systemFont(
                            ofSize: UIFont.preferredFont(forTextStyle: .caption2).pointSize,
                            weight: .bold
                        ),
                        .foregroundColor: UIColor.white,
                    ]
                )
                let textSize = text.size()
                text.draw(at: CGPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2))
            }
        }
        return image.withRenderingMode(.alwaysOriginal)
    }

    private static func aspectFillRect(for pictureSize: CGSize, in bounds: CGRect) -> CGRect {
        guard pictureSize.width > 0, pictureSize.height > 0 else { return bounds }
        let scale = max(bounds.width / pictureSize.width, bounds.height / pictureSize.height)
        let scaled = CGSize(width: pictureSize.width * scale, height: pictureSize.height * scale)
        return CGRect(
            x: bounds.midX - scaled.width / 2,
            y: bounds.midY - scaled.height / 2,
            width: scaled.width,
            height: scaled.height
        )
    }
}
#endif
