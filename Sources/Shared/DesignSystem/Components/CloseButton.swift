import SwiftUI

public struct CloseButton: View {
    @Environment(\.dismiss) private var dismiss
    private let alternativeAction: (() -> Void)?

    /// When alternative action is set, the button will execute this action instead of dismissing the view.
    public init(alternativeAction: (() -> Void)? = nil) {
        self.alternativeAction = alternativeAction
    }

    public var body: some View {
        Button(action: {
            if let alternativeAction {
                alternativeAction()
            } else {
                dismiss()
            }
        }, label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.gray)
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
