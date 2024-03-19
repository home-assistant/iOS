import CoreGraphics
import Foundation
import UIKit

public extension String {
    var djb2hash: Int {
        unicodeScalars.map(\.value).reduce(5381) { ($0 << 5) &+ $0 &+ Int($1) }
    }

    var containsJinjaTemplate: Bool {
        contains("{{") || contains("{%") || contains("{#")
    }
}
