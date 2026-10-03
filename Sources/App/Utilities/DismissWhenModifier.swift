import SwiftUI

/// Dismisses the view it is applied to once `trigger` turns true.
///
/// A view that reads `\.dismiss` itself is evaluated again whenever that action changes. In the native
/// Mac app it changes each time the pages pushed onto the navigation stack are rebuilt, so a view that
/// both builds a pushed page and reads the action never stops updating. Reading it here instead keeps
/// that view out of the cycle.
struct DismissWhenModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    let trigger: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { newValue in
                if newValue {
                    dismiss()
                }
            }
    }
}

extension View {
    func dismiss(when trigger: Bool) -> some View {
        modifier(DismissWhenModifier(trigger: trigger))
    }
}

#Preview {
    Text(verbatim: "Dismissed once the trigger turns true")
        .dismiss(when: false)
}
