#if !os(watchOS)
import SwiftUI

/// The close button of a presented modal, which dismisses it by default.
///
/// Frontend counterpart: the `ha-icon-button` in `ha-dialog-header`'s leading slot. Ported as a
/// button of its own here because SwiftUI dismissal goes through the environment rather than
/// through the dialog element.
public struct ModalCloseButton: View {
    @Environment(\.dismiss) private var dismiss
    private let alternativeAction: (() -> Void)?
    private let tint: Color

    /// When alternative action is set, the button will execute this action instead of dismissing the view.
    public init(
        tint: Color = Color.secondary,
        alternativeAction: (() -> Void)? = nil
    ) {
        self.alternativeAction = alternativeAction
        self.tint = tint
    }

    public var body: some View {
        ModalReusableButton(
            tint: tint,
            icon: .sfSymbol(.xmark),
            action: tapAction
        )
    }

    private func tapAction() {
        if let alternativeAction {
            alternativeAction()
        } else {
            dismiss()
        }
    }
}

#Preview {
    ModalCloseButton(alternativeAction: {
        /* no-op */
    })
}

extension ModalCloseButton: FrontendComponent {
    public static var frontendComponentName: String { "ha-icon-button" }
}

#endif
