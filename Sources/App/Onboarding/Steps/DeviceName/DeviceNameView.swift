import SFSafeSymbols
import Shared
import SwiftUI

struct DeviceNameView: View {
    @State private var deviceName: String = UIDevice.current.name
    let saveAction: (String) -> Void
    let undoOnboarding: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spaces.three) {
                Image(systemSymbol: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
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
                HATextField(placeholder: L10n.DeviceName.Textfield.placeholder, text: $deviceName)
            }
            .padding(DesignSystem.Spaces.two)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                saveAction(deviceName)
            } label: {
                Text(L10n.DeviceName.PrimaryButton.title)
            }
            .buttonStyle(.primaryButton)
            .padding(DesignSystem.Spaces.two)
            .disabled(deviceName.count < 3)
        }
        .interactiveDismissDisabled(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    undoOnboarding()
                } label: {
                    Text(L10n.cancelLabel)
                }
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
}

#Preview {
    DeviceNameView { _ in

    } undoOnboarding: {}
}
