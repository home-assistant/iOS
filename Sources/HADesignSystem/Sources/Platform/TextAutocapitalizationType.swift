#if os(macOS)
import SwiftUI

/// Stands in for `UITextAutocapitalizationType`, which the older `autocapitalization(_:)` modifier takes.
public enum TextAutocapitalizationType {
    case none
    case words
    case sentences
    case allCharacters
}
#endif
