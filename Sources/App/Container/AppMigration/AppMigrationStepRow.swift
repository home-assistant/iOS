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
        HStack(spacing: DesignSystem.Spaces.one) {
            // Fixed tint: the leading icon says *what* the step is, and only the trailing indicator
            // says how it went. Colouring both meant a failed row turned entirely red and a row's
            // identity shifted as it progressed, which made the list harder to scan, not easier.
            AppMigrationRowIcon(symbol: icon)
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
                .foregroundStyle(state == .pending ? Color.secondary : Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            indicator
        }
        .opacity(state == .pending ? 0.45 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: state)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
    }

    private var indicator: some View {
        Image(systemSymbol: indicatorSymbol)
            .imageScale(.large)
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
        // Green rather than the brand tint: while the list is filling in, the checkmarks are the
        // only thing on screen reporting an outcome, and the system's success colour reads as
        // "this worked" at a glance where another blue glyph would just be more blue.
        case .done: return .green
        case .running: return .haPrimary
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
