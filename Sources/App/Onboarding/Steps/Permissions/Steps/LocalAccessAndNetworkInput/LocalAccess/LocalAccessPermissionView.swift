import Shared
import SwiftUI

enum LocalAccessPermissionOptions: String {
    case secure
    case lessSecure
}

struct LocalAccessPermissionViewInNavigationView: View {
    @Environment(\.dismiss) private var dismiss
    let initialSelection: LocalAccessSecurityLevel?
    let action: (LocalAccessSecurityLevel) -> Void

    init(initialSelection: LocalAccessSecurityLevel? = nil, action: @escaping (LocalAccessSecurityLevel) -> Void) {
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
    private let hasInitialSelection: Bool

    init(initialSelection: LocalAccessSecurityLevel? = nil, action: @escaping (LocalAccessSecurityLevel) -> Void) {
        self._viewModel = StateObject(wrappedValue: LocalAccessPermissionViewModel(initialSelection: initialSelection))
        self.hasInitialSelection = initialSelection != nil
        self.action = action
    }

    private let locationOptions = [
        SelectionOption(
            value: LocalAccessSecurityLevel.mostSecure.rawValue,
            title: L10n.Onboarding.LocalAccess.SecureOption.title,
            subtitle: nil,
            isRecommended: true
        ),
        SelectionOption(
            value: LocalAccessSecurityLevel.lessSecure.rawValue,
            title: L10n.Onboarding.LocalAccess.LessSecureOption.title,
            subtitle: nil,
            isRecommended: false
        ),
    ]

    let action: (LocalAccessSecurityLevel) -> Void

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
                        viewModel.selection = LocalAccessSecurityLevel(rawValue: newValue ?? "") ?? .mostSecure
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
            }
        )
    }
}

#Preview {
    LocalAccessPermissionView(initialSelection: .lessSecure) { _ in
    }
}
