import SwiftUI

public struct CloseButton: View {
    public enum Size {
        case small
        case medium
        case large

        var size: CGFloat {
            if Current.isCatalyst {
                switch self {
                case .small:
                    return 24
                case .medium:
                    return 28
                case .large:
                    return 32
                }
            } else {
                switch self {
                case .small:
                    return 20
                case .medium:
                    return 24
                case .large:
                    return 28
                }
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    private let alternativeAction: (() -> Void)?
    private let tint: Color
    private let size: Size

    /// When alternative action is set, the button will execute this action instead of dismissing the view.
    public init(
        tint: Color = Color.gray,
        size: Size = .small,
        alternativeAction: (() -> Void)? = nil
    ) {
        self.alternativeAction = alternativeAction
        self.tint = tint
        self.size = size
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
                .resizable()
                .frame(width: size.size, height: size.size)
                .foregroundStyle(tint)
        })
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        CloseButton {}
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding()
        CloseButton(size: .medium) {}
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding()
        CloseButton(size: .large) {}
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding()
        Spacer()
    }
}
