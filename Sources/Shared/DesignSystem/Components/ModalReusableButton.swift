#if !os(watchOS)
import SwiftUI
import SFSafeSymbols

public struct ModalReusableButton: View {
    public enum Icon {
        case sfSymbol(SFSymbol)
        case mdi(MaterialDesignIcons)
    }
    @Environment(\.dismiss) private var dismiss
    private let action: (() -> Void)
    private let tint: Color
    private let icon: Icon

    private let imageSize: CGSize = .init(width: 16, height: 16)

    /// When alternative action is set, the button will execute this action instead of dismissing the view.
    public init(
        tint: Color = Color.secondary,
        icon: Icon,
        action: @escaping (() -> Void)
    ) {
        self.action = action
        self.icon = icon
        self.tint = tint
    }

    public var body: some View {
        Button(action: {
            action()
        }, label: {
            image
                .modify { view in
                    if #available(iOS 26.0, *) {
                        view
                            .padding(DesignSystem.Spaces.oneAndHalf)
                            .glassEffect(.clear.interactive(), in: .circle)
                    } else {
                        view
                    }
                }
        })
        .buttonStyle(.plain)
        .foregroundStyle(tint)
    }

    private var image: some View {
        Group {
            switch icon {
            case .sfSymbol(let sFSymbol):
                Image(systemSymbol: sFSymbol)
                    .resizable()
                    .frame(width: imageSize.width, height: imageSize.height)
            case .mdi(let materialDesignIcons):
                Image(uiImage: materialDesignIcons.image(ofSize: imageSize, color: UIColor(tint)))
            }
        }
    }
}
#endif


#Preview {
    ModalReusableButton(icon: .sfSymbol(.heart), action: {
        /* no-op */
    })
}
