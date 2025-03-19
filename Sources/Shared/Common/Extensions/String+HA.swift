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

    /// Capitalizes the first character of the string.
    var capitalizedFirst: String {
        guard let first else {
            return self
        }
        return first.uppercased() + dropFirst()
    }
}

public extension String? {
    var orEmpty: String {
        self ?? ""
    }
}
