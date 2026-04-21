import Shared
import SwiftUI

struct RecoveredServersImportView: View {
    let onImport: () -> Void

    @State private var didTriggerImport = false

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.three) {
            Spacer()
            SearchingServersAnimationView()
            VStack(spacing: DesignSystem.Spaces.one) {
                Text(L10n.Onboarding.ServerImport.title)
                    .font(DesignSystem.Font.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(L10n.Onboarding.ServerImport.message)
                    .font(DesignSystem.Font.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DesignSystem.Spaces.three)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .onAppear {
            guard !didTriggerImport else { return }
            didTriggerImport = true
            onImport()
        }
    }
}
