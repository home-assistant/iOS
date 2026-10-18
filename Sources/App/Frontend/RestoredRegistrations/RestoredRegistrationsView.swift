import Shared
import SwiftUI

/// Asks a device restored from another one's backup what to do with the registrations it carries: register itself
/// with those servers as a new device, or keep them because it replaced the other device.
struct RestoredRegistrationsView: View {
    @StateObject private var viewModel: RestoredRegistrationsViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: @autoclosure @escaping () -> RestoredRegistrationsViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.three) {
            // The text scrolls rather than pushing the buttons out of reach at large type sizes.
            ScrollView {
                VStack(spacing: DesignSystem.Spaces.three) {
                    Image(uiImage: MaterialDesignIcons.cellphoneArrowDownVariantIcon.image(
                        ofSize: .init(width: 64, height: 64),
                        color: .haPrimary
                    ))
                    .accessibilityHidden(true)
                    Text(L10n.RestoredRegistrations.title)
                        .font(DesignSystem.Font.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(L10n.RestoredRegistrations.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text(L10n.RestoredRegistrations.servers(viewModel.serverNames))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if let failureMessage = viewModel.failureMessage {
                        Text(failureMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            VStack(spacing: DesignSystem.Spaces.one) {
                Button {
                    Task { await viewModel.registerAsNewDevice() }
                } label: {
                    if viewModel.isRegistering {
                        ProgressView()
                            .tint(.white)
                            .accessibilityLabel(L10n.RestoredRegistrations.progress)
                    } else {
                        Text(L10n.RestoredRegistrations.register)
                    }
                }
                .buttonStyle(.primaryButton)
                Button {
                    viewModel.keepRegistrations()
                } label: {
                    Text(L10n.RestoredRegistrations.keep)
                }
                .buttonStyle(.secondaryButton)
            }
            .disabled(viewModel.isRegistering)
        }
        .padding(.horizontal, DesignSystem.Spaces.three)
        .padding(.top, DesignSystem.Spaces.four)
        .padding(.bottom, DesignSystem.Spaces.one)
        .interactiveDismissDisabled(viewModel.isRegistering)
        .onChange(of: viewModel.isFinished) { isFinished in
            if isFinished {
                dismiss()
            }
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            RestoredRegistrationsView(viewModel: RestoredRegistrationsViewModel(
                servers: FakeServerManager(initial: 2).all
            ))
            .presentationDetents([.medium, .large])
        }
}
