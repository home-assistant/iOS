import Shared
import SwiftUI

struct KioskSettingsEntryCustomizationView: View {
    @ObservedObject var viewModel: KioskSettingsViewModel

    private var backgroundColor: Binding<Color> {
        .init(get: {
            Color(
                hex: viewModel.settings.settingsEntryBackgroundColor ?? KioskSettingsEntryIcon
                    .defaultBackgroundColorHex
            )
        }, set: { newColor in
            viewModel.settings.settingsEntryBackgroundColor = newColor.hex()
        })
    }

    private var iconColor: Binding<Color> {
        .init(get: {
            Color(hex: viewModel.settings.settingsEntryIconColor ?? KioskSettingsEntryIcon.defaultIconColorHex)
        }, set: { newColor in
            viewModel.settings.settingsEntryIconColor = newColor.hex()
        })
    }

    var body: some View {
        List {
            Section(L10n.Kiosk.Customize.Preview.title) {
                HStack {
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(uiColor: .tertiarySystemFill))
                            .frame(height: 140)
                        KioskSettingsEntryIcon(
                            backgroundColor: backgroundColor.wrappedValue,
                            iconColor: iconColor.wrappedValue
                        )
                        .scaleEffect(x: 2, y: 2)
                        .padding(DesignSystem.Spaces.two)
                    }
                    Spacer()
                }
                .padding(.vertical, DesignSystem.Spaces.one)
            }

            Section {
                ColorPicker(
                    L10n.Kiosk.Customize.BackgroundColor.title,
                    selection: backgroundColor,
                    supportsOpacity: false
                )
                ColorPicker(L10n.Kiosk.Customize.IconColor.title, selection: iconColor, supportsOpacity: false)
            }
        }
        .navigationTitle(L10n.Kiosk.Customize.title)
    }
}

#Preview {
    NavigationView {
        KioskSettingsEntryCustomizationView(viewModel: KioskSettingsViewModel())
    }
}
