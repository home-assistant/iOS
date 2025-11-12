import SFSafeSymbols
import Shared
import SwiftUI

struct DeviceNameView: View {
    enum ActionType {
        case save
        case cancel
        case none
    }

    @Environment(\.dismiss) private var dismiss
    @State private var deviceName: String = ""
    let errorMessage: String?
    let saveAction: (String) -> Void
    let cancelAction: () -> Void

    // We can only execute those actions when the view has actually disappeared.
    // similar to UIKit onDismiss completion handler.
    @State private var onDismissAction: ActionType = .none

    var body: some View {
        NavigationView {
            BaseOnboardingView(
                illustration: {
                    Image(.Onboarding.pencil)
                },
                title: L10n.DeviceName.title,
                primaryDescription: L10n.DeviceName.subtitle,
                content: {
                    VStack(spacing: DesignSystem.Spaces.one) {
                        HATextField(placeholder: L10n.DeviceName.Textfield.placeholder, text: $deviceName)
                        if let errorMessage {
                            Text(errorMessage)
                                .font(DesignSystem.Font.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: DesignSystem.List.rowMaxWidth)
                },
                primaryActionTitle: L10n.DeviceName.PrimaryButton.title,
                primaryAction: {
                    onDismissAction = .save
                    dismiss()
                }
            )
            .disableOnboardingPrimaryAction(deviceName.count < 3)
            .onAppear {
                #if DEBUG
                deviceName = "Simulator \(UUID().uuidString.prefix(4))"
                #else
                deviceName = UIDevice.current.name
                #endif
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton(size: .medium) {
                        onDismissAction = .cancel
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .interactiveDismissDisabled(true)
        .onDisappear {
            switch onDismissAction {
            case .save:
                saveAction(deviceName)
            case .cancel:
                cancelAction()
            case .none:
                break
            }
        }
    }

    #if DEBUG
    func setDeviceName(_ deviceName: String) {
        self.deviceName = deviceName
    }
    #endif
}

#Preview {
    DeviceNameView(errorMessage: "Error message") { _ in

    } cancelAction: {}
}
