#if os(macOS)
import SwiftUI

/// Stands in for `UIKeyboardType`. A Mac has one keyboard, so the choice is dropped.
public enum KeyboardType {
    case `default`
    case asciiCapable
    case numbersAndPunctuation
    case URL
    case numberPad
    case phonePad
    case namePhonePad
    case emailAddress
    case decimalPad
    case twitter
    case webSearch
    case asciiCapableNumberPad
}
#endif
