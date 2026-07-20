#if !os(watchOS)
import HAIconic
import SFSafeSymbols
import SwiftUI

public struct ModalReusableButton: View {
    public enum Icon {
        case sfSymbol(SFSymbol)
        case mdi(MaterialDesignIcons)
    }

    private let action: () -> Void
    private let tint: Color
    private let icon: Icon

    private let imageSize: CGSize = .init(width: 16, height: 16)

    /// A reusable icon-only button intended for modal headers/toolbars (executes `action` when tapped).
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
                            .frame(width: 44, height: 44)
                            .glassEffect(.clear.interactive(), in: .circle)
                            .contentShape(Circle())
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
            case let .sfSymbol(sFSymbol):
                Image(systemSymbol: sFSymbol)
                    .resizable()
                    .frame(width: imageSize.width, height: imageSize.height)
            case let .mdi(materialDesignIcons):
                Image(uiImage: materialDesignIcons.image(ofSize: imageSize, color: UIColor(tint)))
            }
        }
    }
}

#Preview {
    ModalReusableButton(icon: .sfSymbol(.heart), action: {
        /* no-op */
    })
}
#endif
