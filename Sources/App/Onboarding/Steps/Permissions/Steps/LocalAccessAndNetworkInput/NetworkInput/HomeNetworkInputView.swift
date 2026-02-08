import Shared
import SwiftUI

struct HomeNetworkInputView: View {
    struct SubmitContext {
        let networkName: String?
        let hardwareAddress: String?
    }

    @State private var networkName: String = ""
    @State private var hardwareAddress: String = ""
    @State private var showingEmptyNetworkAlert = false
    @State private var showLearnMore = false
    @StateObject private var viewModel = HomeNetworkInputViewModel()

    let onNext: (SubmitContext) -> Void

    var body: some View {
        BaseOnboardingView(
            illustration: {
                Image(.Onboarding.lock)
            },
            title: L10n.Onboarding.NetworkInput.title,
            primaryDescription: L10n.Onboarding.NetworkInput.primaryDescription,
            content: {
                networkInputContent
            },
            primaryActionTitle: L10n.Onboarding.NetworkInput.PrimaryButton.title,
            primaryAction: handlePrimaryAction,
            secondaryActionTitle: L10n.SettingsDetails.learnMore,
            secondaryAction: {
                showLearnMore = true
            }
        )
        .alert(L10n.Onboarding.NetworkInput.NoNetwork.Alert.title, isPresented: $showingEmptyNetworkAlert) {
            Button(L10n.okLabel) {}
        } message: {
            Text(L10n.Onboarding.NetworkInput.NoNetwork.Alert.body)
        }
        .sheet(isPresented: $showLearnMore) {
            SafariWebView(url: AppConstants.WebURLs.companionAppConnectionSecurityLevel)
        }
        .onAppear {
            loadCurrentNetworkInfo()
        }
        .onChange(of: viewModel.shouldComplete) { shouldComplete in
            if shouldComplete {
                onNext(.init(networkName: networkName, hardwareAddress: hardwareAddress))
            }
        }
    }

    // MARK: - Content Views

    private var networkInputContent: some View {
        VStack(spacing: DesignSystem.Spaces.two) {
            networkInputField
            if Current.isCatalyst {
                hardwareAddressField
            }
        }
        .frame(maxWidth: DesignSystem.List.rowMaxWidth)
        .padding(.top)
    }

    private var networkInputField: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            Text(L10n.Onboarding.NetworkInput.InputField.title)
                .font(DesignSystem.Font.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HATextField(
                placeholder: L10n.Onboarding.NetworkInput.InputField.placeholder,
                text: $networkName
            )
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
        }
    }

    @ViewBuilder
    private var hardwareAddressField: some View {
        if !hardwareAddress.isEmpty {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                Text(L10n.Onboarding.NetworkInput.Hardware.InputField.title)
                    .font(DesignSystem.Font.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HATextField(
                    placeholder: "00:00:00:00:00:00",
                    text: $hardwareAddress
                )
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            }
        }
    }

    // MARK: - Actions

    private func handlePrimaryAction() {
        let trimmedNetworkName = networkName.trimmingCharacters(in: .whitespacesAndNewlines)
        if Current.isCatalyst {
            let trimmedHardwareAddress = hardwareAddress.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedNetworkName.isEmpty, trimmedHardwareAddress.isEmpty {
                showingEmptyNetworkAlert = true
            } else {
                onNext(.init(networkName: trimmedNetworkName, hardwareAddress: trimmedHardwareAddress))
            }
        } else {
            if trimmedNetworkName.isEmpty {
                showingEmptyNetworkAlert = true
            } else {
                onNext(.init(networkName: trimmedNetworkName, hardwareAddress: hardwareAddress))
            }
        }
    }

    private func loadCurrentNetworkInfo() {
        Current.connectivity.syncNetworkInformation {
            networkName = Current.connectivity.currentWiFiSSID() ?? ""
            hardwareAddress = Current.connectivity.currentNetworkHardwareAddress() ?? ""
        }
    }
}

#Preview {
    NavigationView {
        HomeNetworkInputView(
            onNext: { context in
                // Next tapped with network: \(context.networkName ?? "nil")
            }
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}
