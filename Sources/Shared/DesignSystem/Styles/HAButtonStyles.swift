import Foundation
import SwiftUI

public struct HAButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.bold())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 55)
            .background(Color.asset(Asset.Colors.haPrimary))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

public struct HASecondaryButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.bold())
            .foregroundColor(Color.asset(Asset.Colors.haPrimary))
            .frame(maxWidth: .infinity)
            .frame(height: 55)
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
