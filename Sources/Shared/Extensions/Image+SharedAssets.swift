import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public extension Image {
    init(imageAsset: ImageAsset) {
        self.init(uiImage: imageAsset.image)
    }
}
