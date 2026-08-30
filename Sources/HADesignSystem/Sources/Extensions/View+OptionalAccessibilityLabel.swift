import SwiftUI

/// Applies an accessibility label only when there is one to apply.
///
/// Frontend counterpart: none — a SwiftUI plumbing helper, not a design decision.
public extension View {
    /// `.accessibilityLabel(Text(name ?? ""))` reads as harmless and is worse than saying nothing:
    /// an explicit empty label *silences* the element, so VoiceOver announces a bare "Button" and
    /// cannot say what it does. Leaving the label unset instead lets SwiftUI derive a name from the
    /// children, which for an icon-and-text control is usually the right one.
    @ViewBuilder
    func accessibilityLabel(optional label: String?) -> some View {
        if let label, !label.isEmpty {
            accessibilityLabel(Text(label))
        } else {
            self
        }
    }
}
