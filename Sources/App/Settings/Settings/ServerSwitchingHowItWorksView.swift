import SFSafeSymbols
import Shared
import SwiftUI

struct ServerSwitchingHowItWorksView: View {
    private struct Step: Identifiable {
        let symbol: SFSymbol
        let title: String
        let body: String

        var id: String { title }
    }

    private let decisionSteps: [Step] = [
        Step(
            symbol: .wifi,
            title: L10n.Settings.ServerSwitching.HowItWorks.Wifi.title,
            body: L10n.Settings.ServerSwitching.HowItWorks.Wifi.body
        ),
        Step(
            symbol: .locationFill,
            title: L10n.Settings.ServerSwitching.HowItWorks.Location.title,
            body: L10n.Settings.ServerSwitching.HowItWorks.Location.body
        ),
    ]

    private let behaviorSteps: [Step] = [
        Step(
            symbol: .arrowLeftArrowRight,
            title: L10n.Settings.ServerSwitching.HowItWorks.Switching.title,
            body: L10n.Settings.ServerSwitching.HowItWorks.Switching.body
        ),
        Step(
            symbol: .handRaisedFill,
            title: L10n.Settings.ServerSwitching.HowItWorks.Privacy.title,
            body: L10n.Settings.ServerSwitching.HowItWorks.Privacy.body
        ),
    ]

    var body: some View {
        List {
            Section {
                Text(L10n.Settings.ServerSwitching.HowItWorks.intro)
                    .font(.body)
                    .listRowBackground(Color.clear)
            }

            Section {
                ForEach(decisionSteps) { step in
                    row(for: step)
                }
            }

            Section {
                ForEach(behaviorSteps) { step in
                    row(for: step)
                }
            }
        }
        .navigationTitle(L10n.Settings.ServerSwitching.HowItWorks.title)
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
        ServerSwitchingHowItWorksView()
    }
    .navigationViewStyle(.stack)
}
