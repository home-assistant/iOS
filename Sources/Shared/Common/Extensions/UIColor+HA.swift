import UIKit

public extension UIColor {
    var isLight: Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        /*
         https://www.w3.org/WAI/ER/WD-AERT/#color-contrast
         ((Red value X 299) + (Green value X 587) + (Blue value X 114)) / 1000
         Note: This algorithm is taken from a formula for converting RGB values to YIQ values.
         This brightness value gives a perceived brightness for a color.
         */
        if !getRed(&red, green: &green, blue: &blue, alpha: nil) {
            return false
        }

        let brightness = (red * 299.0 + green * 587.0 + blue * 114.0) / 1000.0
        return brightness > 0.875
    }
}
