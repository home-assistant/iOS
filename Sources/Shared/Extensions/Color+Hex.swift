import Foundation
import SwiftUI

public extension Color {
    init(hex: String) {
        var hex = hex
        if !hex.starts(with: "#") {
            hex = "#\(hex)"
        }
        if let uiColor = UIColor(rgbaString: hex) {
            self.init(uiColor)
        } else {
            self.init(.clear)
        }
    }
}

public extension UIColor {
    convenience init?(rgbaString rgba: String) {
        guard rgba.hasPrefix("#") else { return nil }

        let hexString = String(rgba.dropFirst())
        var hexValue: UInt64 = 0
        guard Scanner(string: hexString).scanHexInt64(&hexValue) else { return nil }

        let shorthandDivisor = CGFloat(15)
        let divisor = CGFloat(255)

        switch hexString.count {
        case 3:
            let value = UInt16(hexValue)
            self.init(
                red: CGFloat((value & 0xF00) >> 8) / shorthandDivisor,
                green: CGFloat((value & 0x0F0) >> 4) / shorthandDivisor,
                blue: CGFloat(value & 0x00F) / shorthandDivisor,
                alpha: 1
            )
        case 4:
            let value = UInt16(hexValue)
            self.init(
                red: CGFloat((value & 0xF000) >> 12) / shorthandDivisor,
                green: CGFloat((value & 0x0F00) >> 8) / shorthandDivisor,
                blue: CGFloat((value & 0x00F0) >> 4) / shorthandDivisor,
                alpha: CGFloat(value & 0x000F) / shorthandDivisor
            )
        case 6:
            let value = UInt32(hexValue)
            self.init(
                red: CGFloat((value & 0xFF0000) >> 16) / divisor,
                green: CGFloat((value & 0x00FF00) >> 8) / divisor,
                blue: CGFloat(value & 0x0000FF) / divisor,
                alpha: 1
            )
        case 8:
            let value = UInt32(hexValue)
            self.init(
                red: CGFloat((value & 0xFF00_0000) >> 24) / divisor,
                green: CGFloat((value & 0x00FF_0000) >> 16) / divisor,
                blue: CGFloat((value & 0x0000_FF00) >> 8) / divisor,
                alpha: CGFloat(value & 0x0000_00FF) / divisor
            )
        default:
            return nil
        }
    }

    convenience init(_ rgba: String, defaultColor: UIColor = .clear) {
        if let color = UIColor(rgbaString: rgba) {
            self.init(cgColor: color.cgColor)
        } else {
            self.init(cgColor: defaultColor.cgColor)
        }
    }

    func hexString(_ includeAlpha: Bool = true) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        guard red >= 0, red <= 1, green >= 0, green <= 1, blue >= 0, blue <= 1 else {
            return ""
        }

        if includeAlpha {
            return String(
                format: "#%02X%02X%02X%02X",
                Int(round(red * 255)),
                Int(round(green * 255)),
                Int(round(blue * 255)),
                Int(round(alpha * 255))
            )
        } else {
            return String(
                format: "#%02X%02X%02X",
                Int(round(red * 255)),
                Int(round(green * 255)),
                Int(round(blue * 255))
            )
        }
    }
}
