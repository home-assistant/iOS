import Foundation
import SwiftUI

@available(iOS 13.0, *)
public extension Image {
    init(asset: ImageAsset) {
        self.init(asset.name, bundle: Bundle(for: SettingsStore.self))
    }
}
