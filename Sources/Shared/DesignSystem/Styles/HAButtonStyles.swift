import Foundation
import SwiftUI

enum HAButtonStylesConstants {
    static var height: CGFloat = 55
    static var cornerRadius: CGFloat = 12
    static var disabledOpacity: CGFloat = 0.5
}

public struct HAButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.bold())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: HAButtonStylesConstants.height)
            .background(isEnabled ? Color.haPrimary : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: HAButtonStylesConstants.cornerRadius))
            .opacity(isEnabled ? 1 : HAButtonStylesConstants.disabledOpacity)
    }
}

public struct HANeutralButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.bold())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: HAButtonStylesConstants.height)
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
            .frame(maxWidth: .infinity)
            .frame(height: HAButtonStylesConstants.height)
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
            .frame(maxWidth: .infinity)
            .frame(height: HAButtonStylesConstants.height)
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
            .frame(maxWidth: .infinity)
            .frame(height: HAButtonStylesConstants.height)
            .clipShape(RoundedRectangle(cornerRadius: HAButtonStylesConstants.cornerRadius))
            .opacity(isEnabled ? 1 : HAButtonStylesConstants.disabledOpacity)
    }
}

public struct HAPillButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.bold())
            .foregroundColor(.white)
            .padding(.vertical, Spaces.one)
            .padding(.horizontal, Spaces.oneAndHalf)
            .background(Color.haPrimary)
            .frame(alignment: .leading)
            .clipShape(Capsule())
    }
}

public struct HACriticalButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .multilineTextAlignment(.center)
            .font(.callout.bold())
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: HAButtonStylesConstants.height)
            .padding()
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
            .frame(maxWidth: .infinity)
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

public extension ButtonStyle where Self == HAPillButtonStyle {
    static var pillButton: HAPillButtonStyle {
        HAPillButtonStyle()
    }
}
