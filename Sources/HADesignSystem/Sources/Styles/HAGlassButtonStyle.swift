#if !os(watchOS)
import SwiftUI

/// A pill button on Liquid Glass, so it can sit over scrolling content without hiding it. Falls
/// back to the regular material where Liquid Glass isn't available.
public struct HAGlassButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.bold())
            .foregroundColor(Color.haPrimary)
            .haButtonFlexSizing()
            .padding(.horizontal, HAButtonStylesConstants.horizontalPadding)
            .modify { view in
                if #available(iOS 26.0, *) {
                    view.glassEffect(.regular.interactive(), in: .capsule)
                } else {
                    view.background(.regularMaterial, in: Capsule())
                }
            }
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : HAButtonStylesConstants.disabledOpacity)
            .haButtonHoverEffect(isEnabled: isEnabled, isPressed: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == HAGlassButtonStyle {
    static var glassButton: HAGlassButtonStyle {
        HAGlassButtonStyle()
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.haPrimary, .orange], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        VStack(spacing: DesignSystem.Spaces.two) {
            Button("Enter address manually") {}
                .buttonStyle(.glassButton)
            Button("Disabled") {}
                .buttonStyle(.glassButton)
                .disabled(true)
        }
    }
}
#endif
