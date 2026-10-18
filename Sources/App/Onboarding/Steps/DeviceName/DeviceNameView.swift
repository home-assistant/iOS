import SFSafeSymbols
import Shared
import SwiftUI

/// Asks the user to name this device during onboarding. Pushed onto the onboarding navigation stack;
/// the cancel button ends the auth flow, and name conflicts surface inline via the request's `errorMessage`.
struct DeviceNameView: View {
    @ObservedObject var request: OnboardingDeviceNameRequest
    @State private var deviceName: String = ""

    var body: some View {
        BaseOnboardingView(
            illustration: {
                Image(.Onboarding.pencil)
            },
            title: L10n.DeviceName.title,
            primaryDescription: L10n.DeviceName.subtitle,
            content: {
                VStack(spacing: DesignSystem.Spaces.one) {
                    HATextField(placeholder: L10n.DeviceName.Textfield.placeholder, text: $deviceName)
                        .disabled(request.isSaving)
                    if let errorMessage = request.errorMessage {
                        Text(errorMessage)
                            .font(DesignSystem.Font.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if request.isSaving {
                        HAProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, DesignSystem.Spaces.one)
                    }
                }
                .frame(maxWidth: DesignSystem.List.rowMaxWidth)
            },
            primaryActionTitle: L10n.DeviceName.PrimaryButton.title,
            primaryAction: {
                request.save(deviceName)
            },
            primaryActionIdentifier: AccessibilityIdentifier.onboardingDeviceNameSave.rawValue
        )
        .disableOnboardingPrimaryAction(deviceName.count < 3 || request.isSaving)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.cancelLabel) {
                    request.cancel()
                }
                .disabled(request.isSaving)
            }
        }
        .onAppear {
            #if DEBUG
            deviceName = "Simulator \(UUID().uuidString.prefix(4))"
            #else
            deviceName = UIDevice.current.name
            #endif
        }
        .onDisappear {
            request.cancel()
        }
    }

    #if DEBUG
    func setDeviceName(_ deviceName: String) {
        self.deviceName = deviceName
    }
    #endif
}

#Preview {
    NavigationView {
        DeviceNameView(request: OnboardingDeviceNameRequest(onSave: { _, request in
            request.fail(with: "Error message")
        }, onCancel: {}))
    }
    .navigationViewStyle(.stack)
}
