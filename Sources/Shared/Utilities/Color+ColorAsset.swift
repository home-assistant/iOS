import Foundation
import SwiftUI

public extension Color {
    static func asset(_ colorAsset: ColorAsset) -> Color {
        Color(colorAsset.name, bundle: Bundle(for: SettingsStore.self))
    }
}
