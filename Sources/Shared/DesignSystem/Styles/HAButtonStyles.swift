import SwiftUI

enum HAButtonStylesConstants {
    static var cornerRadius: CGFloat = 12
    static var disabledOpacity: CGFloat = 0.5
    static var horizontalPadding: CGFloat = 20
}

public struct HAButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .haButtonBasicSizing()
            .padding(.horizontal, HAButtonStylesConstants.horizontalPadding)
            .modify { view in
                if #available(iOS 26.0, watchOS 26.0, *) {
                    view
                        .glassEffect(.regular.interactive().tint(isEnabled ? Color.haPrimary : Color.gray))
                } else {
                    view
                        .background(isEnabled ? Color.haPrimary : Color.gray)
                }
            }
            .clipShape(Capsule())
            .opacity(isEnabled ? 1 : HAButtonStylesConstants.disabledOpacity)
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
    }
}

public struct HACriticalButtonStyle: ButtonStyle {
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
    }
}

public struct HALinkButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote)
            .foregroundColor(Color.haPrimary)
            .frame(maxWidth: DesignSystem.Button.maxWidth)
    }
}

public extension ButtonStyle where Self == HAButtonStyle {
    static var primaryButton: HAButtonStyle {
        HAButtonStyle()
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

private extension View {
    func haButtonBasicSizing() -> some View {
        modifier(HABasicStylingModifier())
    }
}
