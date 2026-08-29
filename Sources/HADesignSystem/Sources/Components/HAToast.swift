#if !os(watchOS)
import SwiftUI

/// A brief message that appears over the content, optionally with one action. The SwiftUI
/// counterpart of the frontend's `ha-toast`.
///
/// Only the surface: when it appears and when it goes away belongs to whatever is presenting it,
/// because a toast's lifetime is tied to the event that caused it. Present it in an `.overlay` at
/// the bottom edge and drive it from your own state — that also keeps it snapshottable, since a
/// toast that dismissed itself on a timer could not be captured twice the same way.
public struct HAToast: View {
    private let message: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(_ message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(spacing: DesignSystem.Spaces.two) {
            Text(message)
                .font(DesignSystem.Font.body)
                .foregroundStyle(Color(uiColor: .systemBackground))
                .frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(DesignSystem.Font.body.weight(.medium))
                    .foregroundStyle(.haPrimary)
            }
        }
        .padding(.horizontal, DesignSystem.Spaces.two)
        .padding(.vertical, DesignSystem.Spaces.oneAndHalf)
        // Inverted against the interface, as a toast is on both platforms: it has to read over
        // whatever content it covers.
        .background(Color(uiColor: .label))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.one))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAToast("Settings saved")
        HAToast("Could not reach the server", actionTitle: "Retry") {}
    }
    .padding()
}

extension HAToast: FrontendComponent {
    public static var frontendComponentName: String { "ha-toast" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
