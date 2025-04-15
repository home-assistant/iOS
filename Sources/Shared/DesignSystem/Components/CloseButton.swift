import SwiftUI

public struct CloseButton: View {
    @Environment(\.dismiss) private var dismiss
    private let alternativeAction: (() -> Void)?
    private let tint: Color

    /// When alternative action is set, the button will execute this action instead of dismissing the view.
    public init(tint: Color = Color.gray, alternativeAction: (() -> Void)? = nil) {
        self.alternativeAction = alternativeAction
        self.tint = tint
    }

    public var body: some View {
        Button(action: {
            if let alternativeAction {
                alternativeAction()
            } else {
                dismiss()
            }
        }, label: {
            Image(systemSymbol: .xmarkCircleFill)
                .font(.body)
                .foregroundStyle(tint)
        })
    }
}

#Preview {
    VStack {
        CloseButton {}
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding()
        Spacer()
    }
}
