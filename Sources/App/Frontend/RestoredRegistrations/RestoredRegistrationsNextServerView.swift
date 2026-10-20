import SFSafeSymbols
import Shared
import SwiftUI

/// The hand-off between two servers while setting a restored device up as a new one: what became of the server
/// just finished, and which server's login opens next, so the next page is never a surprise.
struct RestoredRegistrationsNextServerView: View {
    let next: RestoredRegistrationsViewModel.NextServer

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.three) {
            ScrollView {
                VStack(spacing: DesignSystem.Spaces.three) {
                    HStack(spacing: DesignSystem.Spaces.one) {
                        Image(systemSymbol: previousSymbol)
                            .foregroundStyle(previousColor)
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                            Text(next.previous.info.name)
                                .font(.body)
                            Text(next.previousState.title)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(DesignSystem.Spaces.one)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.one)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
                    .accessibilityElement(children: .combine)
                    Image(systemSymbol: .arrowDownCircleFill)
                        .font(.system(size: 48))
                        .foregroundStyle(.haPrimary)
                        .accessibilityHidden(true)
                    Text(L10n.RestoredRegistrations.Login.progress(next.position, next.count))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(L10n.RestoredRegistrations.Next.title(next.next.info.name))
                        .font(DesignSystem.Font.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(L10n.RestoredRegistrations.Next.body(next.next.info.name))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
            Button(action: next.goOn) {
                Text(L10n.RestoredRegistrations.Next.continue)
            }
            .buttonStyle(.primaryButton)
            .accessibilityIdentifier(AccessibilityIdentifier.restoredRegistrationsNextContinue.rawValue)
        }
        .padding(.horizontal, DesignSystem.Spaces.three)
        .padding(.top, DesignSystem.Spaces.four)
        .padding(.bottom, DesignSystem.Spaces.one)
        .interactiveDismissDisabled()
    }

    private var previousSymbol: SFSymbol {
        switch next.previousState {
        case .done: return .checkmarkCircleFill
        case .skipped: return .minusCircle
        default: return .exclamationmarkCircleFill
        }
    }

    private var previousColor: Color {
        switch next.previousState {
        case .done: return .green
        case .skipped: return .secondary
        default: return .red
        }
    }
}

#Preview {
    let servers = FakeServerManager(initial: 2).all
    Color.clear
        .sheet(isPresented: .constant(true)) {
            RestoredRegistrationsNextServerView(next: .init(
                previous: servers[0],
                previousState: .done,
                next: servers[1],
                position: 2,
                count: 2,
                goOn: {}
            ))
        }
}
