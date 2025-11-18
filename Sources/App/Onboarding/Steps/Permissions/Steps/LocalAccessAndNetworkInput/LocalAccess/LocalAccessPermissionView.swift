import Shared
import SwiftUI

enum LocalAccessPermissionOptions: String {
    case secure
    case lessSecure
}

struct LocalAccessPermissionViewInNavigationView: View {
    @Environment(\.dismiss) private var dismiss
    let initialSelection: ConnectionSecurityLevel?
    let action: (ConnectionSecurityLevel) -> Void

    init(initialSelection: ConnectionSecurityLevel? = nil, action: @escaping (ConnectionSecurityLevel) -> Void) {
        self.initialSelection = initialSelection
        self.action = action
    }

    var body: some View {
        NavigationView {
            LocalAccessPermissionView(initialSelection: initialSelection) { selection in
                action(selection)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct LocalAccessPermissionView: View {
    @StateObject private var viewModel: LocalAccessPermissionViewModel
    @State private var showLearnMore = false
    private let hasInitialSelection: Bool

    init(initialSelection: ConnectionSecurityLevel? = nil, action: @escaping (ConnectionSecurityLevel) -> Void) {
        self._viewModel = StateObject(wrappedValue: LocalAccessPermissionViewModel(initialSelection: initialSelection))
        self.hasInitialSelection = initialSelection != nil
        self.action = action
    }

    private let locationOptions = [
        SelectionOption(
            value: ConnectionSecurityLevel.mostSecure.rawValue,
            title: L10n.Onboarding.LocalAccess.SecureOption.title,
            subtitle: nil,
            isRecommended: true
        ),
        SelectionOption(
            value: ConnectionSecurityLevel.lessSecure.rawValue,
            title: L10n.Onboarding.LocalAccess.LessSecureOption.title,
            subtitle: nil,
            isRecommended: false
        ),
    ]

    let action: (ConnectionSecurityLevel) -> Void

    var body: some View {
        BaseOnboardingView(
            illustration: {
                Image(.Onboarding.lock)
            },
            title: L10n.Onboarding.LocalAccess.title,
            primaryDescription: L10n.Onboarding.LocalAccess.description,
            secondaryDescription: nil,
            content: {
                VStack(spacing: DesignSystem.Spaces.four) {
                    SelectionOptionView(options: locationOptions, selection: .init(get: {
                        viewModel.selection.rawValue
                    }, set: { newValue in
                        viewModel.selection = ConnectionSecurityLevel(rawValue: newValue ?? "") ?? .mostSecure
                    }))
                    HStack(spacing: DesignSystem.Spaces.two) {
                        Image(systemSymbol: .lock)
                            .foregroundStyle(.haPrimary)
                            .font(DesignSystem.Font.body)

                        Text(L10n.Onboarding.LocalAccess.privacyDisclaimer)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spaces.two)
                }
            },
            primaryActionTitle: hasInitialSelection ? L10n.saveLabel : L10n.Onboarding.LocalAccess.nextButton,
            primaryAction: {
                action(viewModel.selection)
            },
            secondaryActionTitle: L10n.SettingsDetails.learnMore,
            secondaryAction: {
                showLearnMore = true
            }
        )
        .sheet(isPresented: $showLearnMore) {
            SafariWebView(url: AppConstants.WebURLs.companionAppConnectionSecurityLevel)
        }
    }
}

#Preview {
    LocalAccessPermissionView(initialSelection: .lessSecure) { _ in
    }
}
