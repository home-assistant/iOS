#if !os(watchOS)
import HAIconic
import SwiftUI

/// The card a dashboard shows in place of one it could not build. The SwiftUI counterpart of the
/// frontend's `hui-error-card`.
///
/// Takes the place of the broken card rather than being hidden, because a card that silently
/// vanishes is harder to diagnose than one that says what went wrong.
public struct HAErrorCard: View {
    /// How bad it is. The frontend's `severity`, which picks the icon and the tint.
    public enum Severity: Sendable {
        case warning
        case error

        var color: Color {
            switch self {
            case .warning: .haWarningColor
            case .error: .haErrorColor
            }
        }

        var icon: MaterialDesignIcons {
            switch self {
            case .warning: .alertOutlineIcon
            case .error: .alertCircleOutlineIcon
            }
        }
    }

    private let title: String
    private let message: String?
    private let severity: Severity

    /// - Parameter message: The detail behind the failure. The frontend shows this only in preview,
    ///   where the person seeing it is the one editing the card; elsewhere the title alone is shown.
    public init(title: String, message: String? = nil, severity: Severity = .error) {
        self.title = title
        self.message = message
        self.severity = severity
    }

    public var body: some View {
        HACard {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                HStack(alignment: .top, spacing: DesignSystem.Spaces.one) {
                    MaterialDesignIconsImage(icon: severity.icon, size: 24)
                        .foregroundStyle(severity.color)
                    Text(title)
                        .font(DesignSystem.Font.body)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: .zero)
                }
                if let message {
                    Text(message)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(DesignSystem.Spaces.two)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAErrorCard(title: "Configuration error")
        HAErrorCard(
            title: "Configuration error",
            message: "Entity not found: sensor.kitchen_temperature"
        )
        HAErrorCard(title: "Configuration warning", severity: .warning)
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAErrorCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-error-card" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
