import SwiftUI
import UIColor_Hex_Swift

extension Color {
    init(hex: String) {
        var hex = hex
        if !hex.starts(with: "#") {
            hex = "#\(hex)"
        }
        if let uiColor = try? UIColor(rgba_throws: hex) {
            self.init(uiColor)
        } else {
            self.init(.clear)
        }
    }
}
