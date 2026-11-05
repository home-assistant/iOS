import Shared
import SwiftUI

/// The notification count capsule drawn over the bell, in the frontend's accent colours; nothing when there are none.
struct NativeTabBarNotificationsBadge: View {
    private enum Constants {
        static let height = DesignSystem.Spaces.two
        static let offset = CGSize(width: DesignSystem.Spaces.one, height: -DesignSystem.Spaces.half)
    }

    let count: Int
    let color: Color
    let textColor: Color

    var body: some View {
        if count > 0 {
            Text(Self.text(for: count))
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(textColor)
                .padding(.horizontal, DesignSystem.Spaces.half)
                .frame(minWidth: Constants.height)
                .frame(height: Constants.height)
                .fixedSize()
                .background(color, in: Capsule())
                .offset(x: Constants.offset.width, y: Constants.offset.height)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// The count as the user reads it, or nothing when the badge is not shown.
    static func text(for count: Int) -> String {
        count > 0 ? NumberFormatter.localizedString(from: NSNumber(value: count), number: .decimal) : ""
    }
}

#Preview {
    HStack(spacing: DesignSystem.Spaces.three) {
        NativeTabBarNotificationsBadge(count: 3, color: .haPrimary, textColor: .white)
        NativeTabBarNotificationsBadge(count: 1234, color: .orange, textColor: .black)
        NativeTabBarNotificationsBadge(count: 0, color: .haPrimary, textColor: .white)
    }
    .padding()
}
