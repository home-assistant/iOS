import Foundation
import SwiftUI
import UIKit

public extension Image {
    init(imageAsset: ImageAsset) {
        self.init(uiImage: imageAsset.image)
    }
}
