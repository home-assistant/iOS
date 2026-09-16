import Foundation

extension AttributedString {
    /// The text without its attributes.
    ///
    /// `String.init` on an `AttributedString` resolves to the debug description, which appends the
    /// attribute runs: a note dictated as "Two pints" becomes `Two pints {\n}`. Home Assistant
    /// stores a note as a plain string and would keep that verbatim, so the characters are what
    /// every schema intent sends.
    var plainText: String {
        String(characters)
    }
}
