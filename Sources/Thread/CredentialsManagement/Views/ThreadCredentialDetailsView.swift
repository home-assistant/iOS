import Shared
import SwiftUI

struct ThreadCredentialDetailsView: View {
    enum ActionButtonState {
        case standard
        case loading
        case success
        case error
    }

    @EnvironmentObject private var viewModel: ThreadCredentialsManagementViewModel
    @State private var actionButtonState: ActionButtonState = .standard
    private let feedbackGenerator = UINotificationFeedbackGenerator()

    let source: HAThreadNetworkConfig.Source
    let credential: ThreadCredential

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            infoRow(header: L10n.Thread.BorderAgentId.title, value: credential.borderAgentID)
            infoRow(header: L10n.Thread.NetworkKey.title, value: credential.networkKey)
            infoRow(header: L10n.Thread.ExtendedPanId.title, value: credential.extendedPANID)
            infoRow(header: L10n.Thread.ActiveOperationalDataSet.title, value: credential.activeOperationalDataSet)
            transferButton
        }
    }

    private var transferButton: some View {
        Button {
            feedbackGenerator.prepare()
            actionButtonState = .loading
            viewModel.transfer(credential, to: source == .HomeAssistant ? .Apple : .HomeAssistant) { success in
                defer {
                    resetActionButtonState()
                }

                if success {
                    actionButtonState = .success
                    feedbackGenerator.notificationOccurred(.success)
                } else {
                    actionButtonState = .error
                    feedbackGenerator.notificationOccurred(.error)
                }
            }
        } label: {
            switch actionButtonState {
            case .standard:
                Text(
                    source == .HomeAssistant ? L10n.Thread.TransterToApple.title : L10n.Thread.TransterToHomeassistant
                        .title
                )
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
            case .success:
                Image(systemName: "checkmark.circle")
            case .error:
                Image(systemName: "xmark.circle")
            }
        }
        .buttonStyle(.plain)
        .disabled(actionButtonState != .standard)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(actionButtonbackgroundColor)
        .foregroundColor(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.top)
    }

    private func resetActionButtonState() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            actionButtonState = .standard
        }
    }

    private var actionButtonbackgroundColor: some View {
        switch actionButtonState {
        case .standard, .loading:
            Color.asset(Asset.Colors.haPrimary)
        case .success:
            Color.green
        case .error:
            Color.red
        }
    }

    @ViewBuilder
    private func infoRow(header: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(header)
                .font(.footnote)
                .foregroundColor(.gray)
            Text(value)
                .textSelection(.enabled)
                .lineLimit(1)
        }
    }
}

#Preview {
    ThreadCredentialDetailsView(
        source: .Apple,
        credential: .init(
            networkName: "MyHOme987654",
            networkKey: "23456",
            extendedPANID: "23456",
            borderAgentID: "23456",
            macExtendedAddress: "123",
            activeOperationalDataSet: "2456",
            pskc: "23456",
            channel: 25,
            panID: "23456"
        )
    )
}
