import Shared
import SwiftUI

/// Explains to a device restored from another one's backup that it still counts as that device in Home Assistant,
/// and lets it sign in and register as a new device, or replace the other device and keep its registrations.
struct RestoredRegistrationsView: View {
    @StateObject private var viewModel: RestoredRegistrationsViewModel

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
                    Text(L10n.RestoredRegistrations.explanation)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text(L10n.RestoredRegistrations.servers(viewModel.serverNames))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text(L10n.RestoredRegistrations.choices)
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
                Button(action: viewModel.startSettingUpAsNewDevice) {
                    Text(viewModel.newDeviceTitle)
                }
                .buttonStyle(.primaryButton)
                Button(action: viewModel.confirmReplacingOldDevice) {
                    Text(L10n.RestoredRegistrations.replaceDevice)
                }
                .buttonStyle(.secondaryButton)
                .confirmationDialog(
                    L10n.RestoredRegistrations.Replace.title,
                    isPresented: $viewModel.isReplaceConfirmationPresented,
                    titleVisibility: .visible
                ) {
                    Button(L10n.RestoredRegistrations.Replace.confirm, action: viewModel.replaceOldDevice)
                    Button(L10n.cancelLabel, role: .cancel) {}
                } message: {
                    Text(L10n.RestoredRegistrations.Replace.message)
                }
            }
            .disabled(viewModel.isRegistering)
        }
        .padding(.horizontal, DesignSystem.Spaces.three)
        .padding(.top, DesignSystem.Spaces.four)
        .padding(.bottom, DesignSystem.Spaces.one)
        .interactiveDismissDisabled(viewModel.isRegistering)
        .sheet(item: $viewModel.login) { login in
            OnboardingAuthLoginView(viewModel: login, style: .modal)
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            RestoredRegistrationsView(viewModel: RestoredRegistrationsViewModel(
                servers: FakeServerManager(initial: 2).all,
                onFinished: {}
            ))
            .presentationDetents([.medium, .large])
        }
}
