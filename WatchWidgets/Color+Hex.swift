import SwiftUI

extension Color {
    /// The Home Assistant primary brand color (`#009AC7`). Mirrors the shared `haPrimary` asset; defined
    /// locally because the WatchWidgets extension does not link the Shared module.
    static let haPrimary = Color(red: 0, green: 154 / 255, blue: 199 / 255)

    init?(hex: String?) {
        guard let hex else { return nil }

        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6 || cleaned.count == 8 else { return nil }

        var value: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&value) else { return nil }

        let components = ColorComponents(value: value, includesAlpha: cleaned.count == 8)
        self.init(
            red: components.red,
            green: components.green,
            blue: components.blue,
            opacity: components.alpha
        )
    }
}

private struct ColorComponents {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(value: UInt64, includesAlpha: Bool) {
        if includesAlpha {
            red = Double((value & 0xFF00_0000) >> 24) / 255
            green = Double((value & 0x00FF_0000) >> 16) / 255
            blue = Double((value & 0x0000_FF00) >> 8) / 255
            alpha = Double(value & 0x0000_00FF) / 255
        } else {
            red = Double((value & 0xFF0000) >> 16) / 255
            green = Double((value & 0x00FF00) >> 8) / 255
            blue = Double(value & 0x0000FF) / 255
            alpha = 1
        }
    }
}
