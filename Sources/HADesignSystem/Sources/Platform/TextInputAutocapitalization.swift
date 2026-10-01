#if os(macOS)
import SwiftUI

/// Stands in for `TextInputAutocapitalization`. A Mac text field never capitalizes on its own.
public enum TextInputAutocapitalization {
    case never
    case words
    case sentences
    case characters
}
#endif
