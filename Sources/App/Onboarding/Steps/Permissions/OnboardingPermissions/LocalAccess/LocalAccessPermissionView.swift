import Shared
import SwiftUI

enum LocalAccessPermissionOptions: String {
    case secure
    case lessSecure
}

struct LocalAccessPermissionView: View {
    @StateObject private var viewModel = LocalAccessPermissionViewModel()

    let completeAction: () -> Void

    private let locationOptions = [
        SelectionOption(
            value: LocalAccessPermissionOptions.secure.rawValue,
            title: "Most secure: Allow this app to know when you're home",
            subtitle: nil,
            isRecommended: true
        ),
        SelectionOption(
            value: LocalAccessPermissionOptions.lessSecure.rawValue,
            title: "Less secure: Do not allow this app to know when you're home",
            subtitle: nil,
            isRecommended: false
        )
    ]

    var body: some View {
        BasePermissionView(
            illustration: {
                Image(.Onboarding.lock)
            },
            title: "Let us help secure your remote connection",
            primaryDescription: "If this app knows when you’re away from home, it can choose a more secure way to connect to your Home Assistant system. This requires location services to be enabled.",
            secondaryDescription: nil,
            content: {
                VStack(spacing: DesignSystem.Spaces.four) {
                    SelectionOptionView(options: locationOptions, selection: $viewModel.selection)

                    HStack(spacing: DesignSystem.Spaces.two) {
                        Image(systemSymbol: .lock)
                            .foregroundStyle(.haPrimary)
                            .font(DesignSystem.Font.body)

                        Text("This data will never be shared with the Home Assistant project or third parties.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spaces.two)
                }
            },
            primaryActionTitle: "Next",
            primaryAction: {
                // Handle selection and continue
                print("Selected option: \(viewModel.selection ?? "None")")
                completeAction()
            },
            secondaryActionTitle: nil,
            secondaryAction: nil
        )
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.shouldComplete) { shouldComplete in
            if shouldComplete {
                completeAction()
            }
        }
    }
}

#Preview {
    LocalAccessPermissionView() {}
}
