import Foundation
import SwiftUI

public struct HAButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.bold())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 55)
            .background(isEnabled ? Color.asset(Asset.Colors.haPrimary) : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(isEnabled ? 1 : 0.5)
    }
}

public struct HASecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.bold())
            .foregroundColor(Color.asset(Asset.Colors.haPrimary))
            .frame(maxWidth: .infinity)
            .frame(height: 55)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(isEnabled ? 1 : 0.5)
    }
}

public struct HAPillButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.bold())
            .foregroundColor(.white)
            .padding(.vertical, Spaces.one)
            .padding(.horizontal, Spaces.oneAndHalf)
            .background(Color.asset(Asset.Colors.haPrimary))
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
            .frame(height: 55)
            .padding()
            .background(.red.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red, lineWidth: 1))
    }
}

public struct HALinkButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote)
            .foregroundColor(Color.asset(Asset.Colors.haPrimary))
            .frame(maxWidth: .infinity)
    }
}

public extension ButtonStyle where Self == HAButtonStyle {
    static var primaryButton: HAButtonStyle {
        HAButtonStyle()
    }
}

public extension ButtonStyle where Self == HASecondaryButtonStyle {
    static var secondaryButton: HASecondaryButtonStyle {
        HASecondaryButtonStyle()
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
