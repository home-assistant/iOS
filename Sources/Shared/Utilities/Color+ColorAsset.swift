import Foundation
import SwiftUI

public extension Color {
    static func asset(_ colorAsset: ColorAsset) -> Color {
        Color(uiColor: colorAsset.color)
    }
}
