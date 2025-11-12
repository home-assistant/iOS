import SwiftUI

enum HAButtonStylesConstants {
    static var cornerRadius: CGFloat = 12
    static var disabledOpacity: CGFloat = 0.5
    static var horizontalPadding: CGFloat = 20
    static var highlightedOpacity: CGFloat = 0.8
    static var highlightedScale: CGFloat = 0.95
    static var hoverOpacity: CGFloat = 0.9
    static var hoverScale: CGFloat = 1.02
    static var animationDuration: Double = 0.1
}

public struct HAButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .haButtonBasicSizing()
            .padding(.horizontal, HAButtonStylesConstants.horizontalPadding)
            .background(backgroundColorForState(
                isEnabled: isEnabled,
                isPressed: configuration.isPressed
            ))
            .clipShape(Capsule())
            .opacity(isEnabled ? 1 : HAButtonStylesConstants.disabledOpacity)
            .haButtonHoverEffect(isEnabled: isEnabled, isPressed: configuration.isPressed)
    }

    private func backgroundColorForState(isEnabled: Bool, isPressed: Bool) -> Color {
        if !isEnabled {
            return Color.gray
        }

        if isPressed {
            return Color.haPrimary.opacity(HAButtonStylesConstants.highlightedOpacity)
        }

        return Color.haPrimary
    }
}

#Preview {
    VStack {
        Button("Primary Button") {}
            .buttonStyle(.primaryButton)
    }
}

public struct HAOutlinedButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(isEnabled ? Color.haPrimary : Color.gray)
            .haButtonFlexSizing()
            .padding(.horizontal, HAButtonStylesConstants.horizontalPadding)
            .overlay(
                Capsule()
                    .stroke(isEnabled ? Color.haColorBorderPrimaryQuiet : Color.gray, lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : HAButtonStylesConstants.disabledOpacity)
            .haButtonHoverEffect(isEnabled: isEnabled, isPressed: configuration.isPressed)
    }
}

public struct HANeutralButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.bold())
            .foregroundColor(.white)
            .haButtonBasicSizing()
            .padding(.horizontal, HAButtonStylesConstants.horizontalPadding)
            .background(Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: HAButtonStylesConstants.cornerRadius))
            .opacity(isEnabled ? 1 : HAButtonStylesConstants.disabledOpacity)
            .haButtonHoverEffect(isEnabled: isEnabled, isPressed: configuration.isPressed)
    }
}

public struct HANegativeButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.bold())
            .foregroundColor(.white)
            .haButtonBasicSizing()
            .padding(.horizontal, HAButtonStylesConstants.horizontalPadding)
            .background(isEnabled ? .red : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: HAButtonStylesConstants.cornerRadius))
            .opacity(isEnabled ? 1 : HAButtonStylesConstants.disabledOpacity)
            .haButtonHoverEffect(isEnabled: isEnabled, isPressed: configuration.isPressed)
    }
}

public struct HASecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.bold())
            .foregroundColor(Color.haPrimary)
            .haButtonBasicSizing()
            .padding(.horizontal, HAButtonStylesConstants.horizontalPadding)
            .clipShape(RoundedRectangle(cornerRadius: HAButtonStylesConstants.cornerRadius))
            .opacity(isEnabled ? 1 : HAButtonStylesConstants.disabledOpacity)
            .haButtonHoverEffect(isEnabled: isEnabled, isPressed: configuration.isPressed)
    }
}

public struct HASecondaryNegativeButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.bold())
            .foregroundColor(.red)
            .haButtonBasicSizing()
            .padding(.horizontal, HAButtonStylesConstants.horizontalPadding)
            .clipShape(RoundedRectangle(cornerRadius: HAButtonStylesConstants.cornerRadius))
            .opacity(isEnabled ? 1 : HAButtonStylesConstants.disabledOpacity)
            .haButtonHoverEffect(isEnabled: isEnabled, isPressed: configuration.isPressed)
    }
}

public struct HACriticalButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .multilineTextAlignment(.center)
            .font(.callout.bold())
            .foregroundColor(.black)
            .haButtonBasicSizing()
            .padding(.horizontal, HAButtonStylesConstants.horizontalPadding)
            .background(.red.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: HAButtonStylesConstants.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: HAButtonStylesConstants.cornerRadius).stroke(
                Color.red,
                lineWidth: 1
            ))
            .haButtonHoverEffect(isEnabled: isEnabled, isPressed: configuration.isPressed)
    }
}

public struct HALinkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote)
            .foregroundColor(Color.haPrimary)
            .frame(maxWidth: DesignSystem.Button.maxWidth)
            .haButtonHoverEffect(isEnabled: isEnabled, isPressed: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == HAButtonStyle {
    static var primaryButton: HAButtonStyle {
        HAButtonStyle()
    }
}

public extension ButtonStyle where Self == HAOutlinedButtonStyle {
    static var outlinedButton: HAOutlinedButtonStyle {
        HAOutlinedButtonStyle()
    }
}

public extension ButtonStyle where Self == HANegativeButtonStyle {
    static var negativeButton: HANegativeButtonStyle {
        HANegativeButtonStyle()
    }
}

public extension ButtonStyle where Self == HANeutralButtonStyle {
    static var neutralButton: HANeutralButtonStyle {
        HANeutralButtonStyle()
    }
}

public extension ButtonStyle where Self == HASecondaryButtonStyle {
    static var secondaryButton: HASecondaryButtonStyle {
        HASecondaryButtonStyle()
    }
}

public extension ButtonStyle where Self == HASecondaryNegativeButtonStyle {
    static var secondaryNegativeButton: HASecondaryNegativeButtonStyle {
        HASecondaryNegativeButtonStyle()
    }
}

public extension ButtonStyle where Self == HALinkButtonStyle {
    static var linkButton: HALinkButtonStyle {
        HALinkButtonStyle()
    }
}

public extension ButtonStyle where Self == HACriticalButtonStyle {
    static var criticalButton: HACriticalButtonStyle {
        HACriticalButtonStyle()
    }
}

private struct HABasicStylingModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(minHeight: DesignSystem.Button.minHeight)
            .frame(maxWidth: DesignSystem.Button.maxWidth)
    }
}

private struct HAFlexStylingModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(minHeight: DesignSystem.Button.minHeight)
    }
}

private extension View {
    func haButtonBasicSizing() -> some View {
        modifier(HABasicStylingModifier())
    }

    func haButtonFlexSizing() -> some View {
        modifier(HAFlexStylingModifier())
    }

    func haButtonHoverEffect(isEnabled: Bool, isPressed: Bool) -> some View {
        modifier(HAButtonHoverEffectModifier(isEnabled: isEnabled, isPressed: isPressed))
    }
}

private struct HAButtonHoverEffectModifier: ViewModifier {
    let isEnabled: Bool
    let isPressed: Bool
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(scaleForState(isPressed: isPressed, isHovering: isHovering))
            .animation(.easeInOut(duration: HAButtonStylesConstants.animationDuration), value: isPressed)
            .animation(.easeInOut(duration: HAButtonStylesConstants.animationDuration), value: isHovering)
        #if !os(watchOS)
            .onHover { hovering in
                if isEnabled {
                    isHovering = hovering
                }
            }
        #endif
    }

    private func scaleForState(isPressed: Bool, isHovering: Bool) -> CGFloat {
        if isPressed {
            return HAButtonStylesConstants.highlightedScale
        }

        if isHovering {
            return HAButtonStylesConstants.hoverScale
        }

        return 1.0
    }
}
