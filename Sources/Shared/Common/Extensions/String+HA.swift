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
            // Pad each component to 2 characters with leading zeros
            // Components should be 1 or 2 characters for valid MAC addresses
            component.count == 1 ? "0" + component : String(component)
        }.joined(separator: ":")
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    /// Home Assistant sometimes ships a raw translation key where a name or description is
    /// expected; those are useless as display text, so they read as absent.
    var nilIfEmptyUnlessTranslationKey: String? {
        guard let value = nilIfEmpty else {
            return nil
        }
        return value.hasPrefix("component.") || value.hasPrefix("component::") ? nil : value
    }

    /// Substitutes `{key}` placeholders, as used by Home Assistant's action descriptions.
    func applying(placeholders: [String: String]) -> String {
        placeholders.reduce(self) { value, placeholder in
            value.replacingOccurrences(of: "{\(placeholder.key)}", with: placeholder.value)
        }
    }
}

public extension String? {
    var orEmpty: String {
        self ?? ""
    }
}
