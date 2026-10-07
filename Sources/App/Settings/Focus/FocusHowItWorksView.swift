import SFSafeSymbols
import Shared
import SwiftUI

struct FocusHowItWorksView: View {
    private struct Step: Identifiable {
        let symbol: SFSymbol
        let title: String
        let body: String

        var id: String { title }
    }

    private let setupSteps: [Step] = [
        Step(
            symbol: .tag,
            title: L10n.Focus.HowItWorks.Naming.title,
            body: L10n.Focus.HowItWorks.Naming.body
        ),
        Step(
            symbol: .gearshape,
            title: L10n.Focus.HowItWorks.Filter.title,
            body: L10n.Focus.HowItWorks.Filter.body
        ),
        Step(
            symbol: .antennaRadiowavesLeftAndRight,
            title: L10n.Focus.HowItWorks.Reporting.title,
            body: L10n.Focus.HowItWorks.Reporting.body
        ),
    ]

    private let behaviorSteps: [Step] = [
        Step(
            symbol: .moon,
            title: L10n.Focus.HowItWorks.NoFocus.title,
            body: L10n.Focus.HowItWorks.NoFocus.body
        ),
        Step(
            symbol: .questionmarkCircle,
            title: L10n.Focus.HowItWorks.Unpaired.title,
            body: L10n.Focus.HowItWorks.Unpaired.body
        ),
        Step(
            symbol: .handRaisedFill,
            title: L10n.Focus.HowItWorks.Privacy.title,
            body: L10n.Focus.HowItWorks.Privacy.body
        ),
    ]

    var body: some View {
        List {
            Section {
                Text(L10n.Focus.HowItWorks.intro)
                    .font(.body)
                    .listRowBackground(Color.clear)
            }

            Section {
                ForEach(setupSteps) { step in
                    row(for: step)
                }
            }

            Section {
                ForEach(behaviorSteps) { step in
                    row(for: step)
                }
            }
        }
        .navigationTitle(L10n.Focus.HowItWorks.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(for step: Step) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spaces.two) {
            Image(systemSymbol: step.symbol)
                .font(.title3)
                .foregroundStyle(.haPrimary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                Text(step.title)
                    .font(.headline)
                Text(step.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DesignSystem.Spaces.half)
    }
}

#Preview {
    NavigationView {
        FocusHowItWorksView()
    }
    .navigationViewStyle(.stack)
}
