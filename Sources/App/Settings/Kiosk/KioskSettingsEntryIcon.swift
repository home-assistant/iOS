import SFSafeSymbols
import Shared
import SwiftUI

struct KioskSettingsEntryIcon: View {
    static let defaultBackgroundColorHex = "000000"
    static let defaultIconColorHex = "FFFFFF"

    var backgroundColor: Color
    var iconColor: Color
    /// Hidden means invisible, not gone: the icon keeps its place and its hit area, so whoever set the
    /// device up can still tap the corner they chose to reach kiosk settings.
    var isHidden: Bool = false

    var body: some View {
        Image(systemSymbol: .gearshapeFill)
            .font(.body)
            .foregroundStyle(iconColor)
            .padding(DesignSystem.Spaces.one)
            .background(backgroundColor)
            .clipShape(.circle)
            .opacity(isHidden ? 0 : 1)
            .contentShape(Circle())
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        KioskSettingsEntryIcon(backgroundColor: .black, iconColor: .white)
        KioskSettingsEntryIcon(backgroundColor: .black, iconColor: .white, isHidden: true)
    }
    .padding(DesignSystem.Spaces.two)
}
