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

    var leadingCapitalized: String {
        guard let first else {
            return self
        }
        return first.uppercased() + dropFirst()
    }

    /// Formats a BSSID MAC address with proper zero-padding for each octet.
    /// Converts "18:e8:29:a7:e9:b" to "18:e8:29:a7:e9:0b"
    var formattedBSSID: String {
        let components = split(separator: ":")
        guard components.count == 6 else {
            // Not a valid MAC address format, return as-is
            return self
        }
        return components.map { component -> String in
            let hex = String(component)
            // Pad each component to 2 characters with leading zeros
            return hex.count == 1 ? "0" + hex : hex
        }.joined(separator: ":")
    }
}

public extension String? {
    var orEmpty: String {
        self ?? ""
    }
}
