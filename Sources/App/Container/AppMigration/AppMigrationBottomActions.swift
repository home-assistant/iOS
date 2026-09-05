import Shared
import SwiftUI

/// The button pair pinned under the migration screens.
///
/// `BaseOnboardingView` provides this for the screens built on it; the list-based screens cannot use
/// that scaffold, so this keeps their buttons identical rather than approximately similar.
///
/// Pinned over the list, with an opaque background rather than a material: rows scrolling underneath
/// a translucent bar read as a rendering glitch, and the buttons have to stay legible over whatever
/// happens to be behind them.
struct AppMigrationBottomActions: View {
    let primaryTitle: String
    let primaryAction: () -> Void
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            Button(action: primaryAction) {
                Text(primaryTitle)
            }
            .buttonStyle(.primaryButton)

            if let secondaryTitle, let secondaryAction {
                Button(action: secondaryAction) {
                    Text(secondaryTitle)
                }
                .buttonStyle(.secondaryButton)
                .tint(Color.haPrimary)
            }
        }
        .padding(.bottom, Current.isCatalyst ? DesignSystem.Spaces.two : DesignSystem.Spaces.one)
        .frame(maxWidth: Sizes.maxWidthForLargerScreens)
        .padding([.horizontal, .top], DesignSystem.Spaces.two)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

#Preview {
    List {
        ForEach(0 ..< 20) { index in
            Text("Row \(index)")
        }
    }
    .safeAreaInset(edge: .bottom) {
        AppMigrationBottomActions(
            primaryTitle: "Move my data",
            primaryAction: {},
            secondaryTitle: "Not now",
            secondaryAction: {}
        )
    }
}
