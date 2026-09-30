import Foundation
import SwiftUI

public extension Image {
    init(imageAsset: ImageAsset) {
        self.init(uiImage: imageAsset.image)
    }
}
