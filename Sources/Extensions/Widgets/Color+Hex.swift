import SwiftUI
import UIColorHexSwift

extension Color {
    init(hex: String) {
        if let uiColor = try? UIColor(rgba_throws: hex) {
            self.init(uiColor)
        } else {
            self.init(.clear)
        }
    }
}
