import Shared
import SwiftUI

struct HomeNetworkInputView: View {
    @State private var networkName: String = ""
    @State private var showingEmptyNetworkAlert = false
    @StateObject private var viewModel = HomeNetworkInputViewModel()

    let onNext: (String?) -> Void

    var body: some View {
        BaseOnboardingView(
            illustration: {
                Image(.Onboarding.lock)
            },
            title: L10n.Onboarding.NetworkInput.title,
            primaryDescription: L10n.Onboarding.NetworkInput.primaryDescription,
            content: {
                VStack(spacing: DesignSystem.Spaces.two) {
                    // Network input field
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

                    HStack(alignment: .top, spacing: DesignSystem.Spaces.one) {
                        Image(systemSymbol: .infoCircleFill)
                            .foregroundStyle(.blue)
                            .font(.system(size: 20))

                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                            Text(L10n.Onboarding.NetworkInput.Disclaimer.title)
                                .font(DesignSystem.Font.body.weight(.medium))

                            Text(
                                L10n.Onboarding.NetworkInput.Disclaimer.body
                            )
                            .font(DesignSystem.Font.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(DesignSystem.Spaces.two)
                    .background(.blue.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.three)
                }
                .frame(maxWidth: DesignSystem.List.rowMaxWidth)
                .padding(.top)
            },
            primaryActionTitle: L10n.Onboarding.NetworkInput.PrimaryButton.title,
            primaryAction: {
                let trimmedNetworkName = networkName.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedNetworkName.isEmpty {
                    showingEmptyNetworkAlert = true
                } else {
                    onNext(trimmedNetworkName)
                }
            }
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
                onNext(networkName)
            }
        }
    }

    private func loadCurrentNetworkInfo() {
        Task {
            let networkInfo = await Current.networkInformation
            networkName = networkInfo?.ssid ?? ""
        }
    }
}

#Preview {
    NavigationView {
        HomeNetworkInputView(
            onNext: { networkName in
                print("Next tapped with network: \(networkName ?? "nil")")
            }
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}
