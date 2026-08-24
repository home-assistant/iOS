import SFSafeSymbols
import Shared
import SwiftUI

/// One line of the migration progress list: the step's icon and title on the left, and on the right
/// an indicator that morphs from waiting, to working, to a checkmark — or a warning triangle.
///
/// The indicator is a symbol in every state rather than a `ProgressView` while running, so the
/// changes go through `.contentTransition(.symbolEffect(.replace))` and one glyph becomes the next
/// instead of one view being swapped for another. The step list is the only thing on screen during a
/// migration; how it moves is most of what tells the user it is working.
struct AppMigrationStepRow: View {
    let title: String
    let icon: SFSymbol
    let state: AppMigrationStepState

    var body: some View {
        HStack(spacing: DesignSystem.Spaces.two) {
            Image(systemSymbol: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundStyle(iconColor)
                .modify { view in
                    if #available(iOS 17.0, *) {
                        // A small kick as the step picks up, so the eye lands on the row that is
                        // working without the row having to change size or position.
                        view.symbolEffect(.bounce, value: state == .running)
                    } else {
                        view
                    }
                }

            Text(title)
                .font(DesignSystem.Font.body)
                .foregroundStyle(state == .pending ? Color.secondary : Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            indicator
                .frame(width: 24, height: 24)
        }
        .padding(.vertical, DesignSystem.Spaces.one)
        .opacity(state == .pending ? 0.45 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: state)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
    }

    private var indicator: some View {
        Image(systemSymbol: indicatorSymbol)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(indicatorColor)
            .modify { view in
                if #available(iOS 17.0, *) {
                    view.contentTransition(.symbolEffect(.replace.downUp))
                } else {
                    view
                }
            }
    }

    private var indicatorSymbol: SFSymbol {
        switch state {
        case .pending: return .circleDotted
        case .running: return .circleDashed
        case .done: return .checkmarkCircleFill
        case .failed: return .exclamationmarkTriangleFill
        }
    }

    private var indicatorColor: Color {
        switch state {
        case .pending: return .secondary
        case .running, .done: return .haPrimary
        case .failed: return .red
        }
    }

    private var iconColor: Color {
        switch state {
        case .pending: return .secondary
        case .running, .done: return .haPrimary
        case .failed: return .red
        }
    }

    private var accessibilityValue: String {
        switch state {
        case .pending: return L10n.AppMigration.Step.Accessibility.pending
        case .running: return L10n.AppMigration.Step.Accessibility.running
        case .done: return L10n.AppMigration.Step.Accessibility.done
        case .failed: return L10n.AppMigration.Step.Accessibility.failed
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        AppMigrationStepRow(title: "Collecting your servers", icon: .serverRack, state: .done)
        AppMigrationStepRow(title: "Collecting your configuration", icon: .gearshape, state: .running)
        AppMigrationStepRow(title: "Packaging your data", icon: .shippingboxFill, state: .pending)
        AppMigrationStepRow(title: "Opening the new app", icon: .arrowRightCircleFill, state: .failed)
    }
    .padding()
}
