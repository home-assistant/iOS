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
    @State private var deviceName: String = UIDevice.current.name
    let errorMessage: String?
    let saveAction: (String) -> Void
    let cancelAction: () -> Void

    // We can only execute those actions when the view has actually disappeared.
    // similar to UIKit onDismiss completion handler.
    @State private var onDismissAction: ActionType = .none

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spaces.three) {
                    Image(systemSymbol: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(height: OnboardingConstants.iconSize)
                        .foregroundStyle(.haPrimary)
                    Text(L10n.DeviceName.title)
                        .font(DesignSystem.Font.largeTitle.bold())
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                    Text(L10n.DeviceName.subtitle)
                        .font(DesignSystem.Font.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                    VStack(spacing: DesignSystem.Spaces.one) {
                        HATextField(placeholder: L10n.DeviceName.Textfield.placeholder, text: $deviceName)
                        if let errorMessage {
                            Text(errorMessage)
                                .font(DesignSystem.Font.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(DesignSystem.Spaces.two)
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
        .safeAreaInset(edge: .bottom) {
            Button {
                onDismissAction = .save
                dismiss()
            } label: {
                Text(L10n.DeviceName.PrimaryButton.title)
            }
            .buttonStyle(.primaryButton)
            .padding(DesignSystem.Spaces.two)
            .disabled(deviceName.count < 3)
        }
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

    private var icon: SFSymbol {
        if #available(iOS 16.1, *) {
            .macbookAndIphone
        } else {
            .iphone
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
