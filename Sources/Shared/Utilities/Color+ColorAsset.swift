import Foundation
import SwiftUI

@available(iOS 13.0, *)
public extension Color {
    static func asset(_ colorAsset: ColorAsset) -> Color {
        Color(colorAsset.name, bundle: Bundle(for: SettingsStore.self))
    }
}
