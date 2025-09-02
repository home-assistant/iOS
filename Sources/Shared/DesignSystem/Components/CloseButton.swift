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
    private let forceIconOnly: Bool

    /// When alternative action is set, the button will execute this action instead of dismissing the view.
    public init(
        tint: Color = Color.secondary,
        size: Size = .small,
        forceIconOnly: Bool = false,
        alternativeAction: (() -> Void)? = nil
    ) {
        self.alternativeAction = alternativeAction
        self.tint = tint
        self.size = size
        self.forceIconOnly = forceIconOnly
    }

    public var body: some View {
        if #available(iOS 26.0, *) {
            if forceIconOnly {
                Button(action: {
                    tapAction()
                }, label: {
                    Image(systemSymbol: .xmark)
                })
                .buttonStyle(.glass)
            } else {
                Button(role: .close) {
                    tapAction()
                }
            }
        } else {
            Button(action: {
                tapAction()
            }, label: {
                Image(systemSymbol: .xmarkCircleFill)
                    .resizable()
                    .frame(width: size.size, height: size.size)
                    .foregroundStyle(tint)
            })
            .buttonStyle(.plain)
        }
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
