#if !os(watchOS)
import SwiftUI

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
#endif
