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
            primaryAction: handlePrimaryAction
        )
        .alert(L10n.Onboarding.NetworkInput.NoNetwork.Alert.title, isPresented: $showingEmptyNetworkAlert) {
            Button(L10n.okLabel) {}
        } message: {
            Text(L10n.Onboarding.NetworkInput.NoNetwork.Alert.body)
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
            networkDisclaimer
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

    private var hardwareAddressField: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            Text("Hardware Address (BSSID)")
                .font(DesignSystem.Font.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HATextField(
                placeholder: "00:00:00:00:00:00",
                text: $hardwareAddress
            )
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .opacity(hardwareAddress.isEmpty ? 0 : 1)
        }
    }

    private var networkDisclaimer: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spaces.one) {
            Image(systemSymbol: .infoCircleFill)
                .foregroundStyle(.blue)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                Text(L10n.Onboarding.NetworkInput.Disclaimer.title)
                    .font(DesignSystem.Font.body.weight(.medium))

                Text(L10n.Onboarding.NetworkInput.Disclaimer.body)
                    .font(DesignSystem.Font.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DesignSystem.Spaces.two)
        .background(.blue.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.three)
    }

    // MARK: - Actions

    private func handlePrimaryAction() {
        let trimmedNetworkName = networkName.trimmingCharacters(in: .whitespacesAndNewlines)
        if Current.isCatalyst {
            let trimmedHardwareAddress = hardwareAddress.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedNetworkName.isEmpty, trimmedHardwareAddress.isEmpty {
                showingEmptyNetworkAlert = true
            } else {
                onNext(.init(networkName: trimmedNetworkName, hardwareAddress: hardwareAddress))
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
        Task {
            let networkInfo = await Current.networkInformation
            networkName = networkInfo?.ssid ?? ""
        }
        hardwareAddress = Current.connectivity.currentNetworkHardwareAddress() ?? ""
    }
}

#Preview {
    NavigationView {
        HomeNetworkInputView(
            onNext: { context in
                print("Next tapped with network: \(context.networkName ?? "nil")")
            }
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}
