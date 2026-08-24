import SFSafeSymbols
import Shared
import SwiftUI

/// The step list shown while data is packaged or applied. Each row fills in as its step finishes, so
/// the user watches the migration happen rather than staring at one spinner.
///
/// This is the only screen in the flow not built on `BaseOnboardingView` — it has no action button to
/// offer — so it reproduces that view's vertical rhythm by hand: illustration, title, subtitle, then
/// content, all top-aligned. Centring it instead would drop the title well below where it sits on the
/// screens either side of this one.
struct AppMigrationProgressView<Step: AppMigrationStepDescribing>: View where Step.AllCases == [Step] {
    let symbol: SFSymbol
    let title: String
    let subtitle: String
    let state: (Step) -> AppMigrationStepState
    /// Only set while a payload is crossing in more than one link; `nil` for the common single-link
    /// handoff, which has no round trips worth drawing a bar for.
    var transfer: AppMigrationTransferProgress?
    var transferCaption: String = ""

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.three) {
            AppMigrationIllustration(symbol: symbol)
                .padding(.top, DesignSystem.Spaces.two)

            Text(title)
                .font(DesignSystem.Font.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spaces.two)

            Text(subtitle)
                .font(DesignSystem.Font.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spaces.two)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Step.allCases) { step in
                    AppMigrationStepRow(title: step.title, icon: step.icon, state: state(step))
                }
            }
            .padding(.horizontal, DesignSystem.Spaces.two)

            if let transfer {
                AppMigrationTransferProgressView(progress: transfer, caption: transferCaption)
                    .transition(.opacity)
            }

            Spacer(minLength: DesignSystem.Spaces.four)
        }
        .frame(maxWidth: Sizes.maxWidthForLargerScreens)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(uiColor: .systemBackground))
    }
}

#Preview {
    AppMigrationProgressView<AppMigrationExportStep>(
        symbol: .trayAndArrowUpFill,
        title: "Moving your data",
        subtitle: "This only takes a moment. Keep the app open.",
        state: { step in
            switch step {
            case .servers: return .done
            case .configuration: return .running
            case .packaging: return .done
            case .handoff: return .running
            }
        },
        transfer: .init(completed: 2, total: 5),
        transferCaption: "Part 3 of 5 — this app and the new one will swap a few times."
    )
}
