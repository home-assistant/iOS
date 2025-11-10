import SFSafeSymbols
import Shared
import SwiftUI

struct DeviceNameView: View, KeyboardReadable {
    enum ActionType {
        case save
        case cancel
        case none
    }

    @Environment(\.dismiss) private var dismiss
    @State private var deviceName: String = ""
    @State private var isKeyboardVisible = false

    let errorMessage: String?
    let saveAction: (String) -> Void
    let cancelAction: () -> Void

    // We can only execute those actions when the view has actually disappeared.
    // similar to UIKit onDismiss completion handler.
    @State private var onDismissAction: ActionType = .none

    var body: some View {
        NavigationView {
            BaseOnboardingView(illustration: {
                Image(.Onboarding.pencil)
            }, title: L10n.DeviceName.title, primaryDescription: L10n.DeviceName.subtitle, content: {
                VStack(spacing: DesignSystem.Spaces.one) {
                    HATextField(placeholder: L10n.DeviceName.Textfield.placeholder, text: $deviceName)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(DesignSystem.Font.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }, primaryActionTitle: L10n.DeviceName.PrimaryButton.title) {
                onDismissAction = .save
                dismiss()
            }
            .hideOnboardingHeader(isKeyboardVisible)
            .navigationViewStyle(.stack)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton(size: .medium) {
                        onDismissAction = .cancel
                        dismiss()
                    }
                }
            }
            .onAppear {
                #if DEBUG
                deviceName = "Simulator \(UUID().uuidString.prefix(4))"
                #else
                deviceName = UIDevice.current.name
                #endif
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
        .onReceive(keyboardPublisher) { newIsKeyboardVisible in
            isKeyboardVisible = newIsKeyboardVisible
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
