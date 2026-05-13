import Foundation
import SwiftUI

public extension Color {
    init(hex: String?) {
        guard let hex else {
            Current.Log.error("No hex provided when initializing color")
            self.init(uiColor: UIColor(Color.haPrimary))
            return
        }
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0

        let length = hexSanitized.count

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            Current.Log.error("Invalid hex color: \(hexSanitized)")
            self.init(uiColor: UIColor(Color.haPrimary))
            return
        }

        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0

        } else if length == 8 {
            r = CGFloat((rgb & 0xFF00_0000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF_0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000_FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x0000_00FF) / 255.0

        } else {
            Current.Log.error("Invalid hex color (2): \(hexSanitized)")
            self.init(uiColor: UIColor(Color.haPrimary))
            return
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }

    func hex() -> String? {
        let uic = UIColor(self)

        // `cgColor.components` only exposes three values for RGB color spaces. Grayscale
        // colors (e.g. `.white`, `.black`, anything picked from the system grayscale
        // gamut) report two components and previously caused this method to return nil,
        // breaking ColorPicker round-trips. Use `getRed:green:blue:alpha:` instead — it
        // converts grayscale colors to their RGB equivalents.
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 1
        guard uic.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return nil
        }

        let rf = Float(r)
        let gf = Float(g)
        let bf = Float(b)
        let af = Float(a)

        if af != Float(1.0) {
            return String(
                format: "%02lX%02lX%02lX%02lX",
                lroundf(rf * 255),
                lroundf(gf * 255),
                lroundf(bf * 255),
                lroundf(af * 255)
            )
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(rf * 255), lroundf(gf * 255), lroundf(bf * 255))
        }
    }
}
