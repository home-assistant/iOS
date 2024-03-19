import CoreGraphics
import Foundation
import UIKit

extension String {
    public var djb2hash: Int {
        unicodeScalars.map(\.value).reduce(5381) { ($0 << 5) &+ $0 &+ Int($1) }
    }

    public var containsJinjaTemplate: Bool {
        contains("{{") || contains("{%") || contains("{#")
    }
}
