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
        Button(action: {
            tapAction()
        }, label: {
            Image(systemSymbol: .xmark)
                .resizable()
                .frame(width: 16, height: 16)
        })
        .buttonStyle(.plain)
        .foregroundStyle(tint)
    }

    private func tapAction() {
        if let alternativeAction {
            alternativeAction()
        } else {
            dismiss()
        }
    }
}
#endif
