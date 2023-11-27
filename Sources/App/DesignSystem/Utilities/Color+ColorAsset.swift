import Foundation
import SwiftUI

@available(iOS 13.0, *)
extension Color {
    static func asset(_ colorAsset: ColorAsset) -> Color {
        Color(colorAsset.name)
    }
}
