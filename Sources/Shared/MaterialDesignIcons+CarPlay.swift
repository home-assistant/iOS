import CarPlay
import Foundation
import UIKit

public extension MaterialDesignIcons {
    func carPlayIcon(color: UIColor? = nil) -> UIImage {
        let color = color ?? .haPrimary
        return image(ofSize: CPListItem.maximumImageSize, color: color)
    }

    @available(iOS 26.0, *)
    func carPlayCondensedElementImage(
        color: UIColor? = nil
    ) -> UIImage {
        let color = color ?? .haPrimary
        return image(
            ofSize: CPListImageRowItemCondensedElement.maximumImageSize,
            color: color
        ).carPlayCondensedElementImage(iconColor: color)
    }

    func carPlayGridIcon(color: UIColor? = nil) -> UIImage {
        let color = color ?? .haPrimary
        let size: CGSize

        if #available(iOS 26.0, *) {
            size = CPListTemplate.maximumGridButtonImageSize
        } else {
            size = CGSize(width: 60, height: 60)
        }

        return image(ofSize: size, color: color)
    }
}

public extension UIImage {
    @available(iOS 26.0, *)
    func carPlayCondensedElementImage(
        iconColor: UIColor? = nil
    ) -> UIImage {
        let resolvedIconColor = iconColor ?? representativeVisibleColor() ?? .haPrimary
        let size = CPListImageRowItemCondensedElement.maximumImageSize
        let bounds = CGRect(origin: .zero, size: size)
        let padding = DesignSystem.Spaces.one
        let imageRect = bounds.insetBy(dx: padding, dy: padding)

        return UIGraphicsImageRenderer(
            size: size,
            format: with(UIGraphicsImageRendererFormat.preferred()) {
                $0.opaque = false
            }
        ).image { _ in
            resolvedIconColor.withAlphaComponent(0.2).setFill()
            UIBezierPath(
                roundedRect: bounds,
                cornerRadius: DesignSystem.CornerRadius.oneAndHalf
            ).fill()
            draw(in: imageRect)
        }
    }

    private func representativeVisibleColor() -> UIColor? {
        guard let cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var totalAlpha = 0.0
        var totalRed = 0.0
        var totalGreen = 0.0
        var totalBlue = 0.0

        for pixelIndex in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
            let alpha = Double(pixelData[pixelIndex + 3]) / 255.0
            guard alpha > 0 else { continue }

            totalAlpha += alpha
            totalRed += Double(pixelData[pixelIndex]) * alpha
            totalGreen += Double(pixelData[pixelIndex + 1]) * alpha
            totalBlue += Double(pixelData[pixelIndex + 2]) * alpha
        }

        guard totalAlpha > 0 else { return nil }

        return UIColor(
            red: totalRed / totalAlpha / 255.0,
            green: totalGreen / totalAlpha / 255.0,
            blue: totalBlue / totalAlpha / 255.0,
            alpha: 1
        )
    }
}
