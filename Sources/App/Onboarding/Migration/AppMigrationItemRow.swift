import Shared
import SwiftUI

/// One line of the transfer inventory: a tinted icon, the item and a one-line caption.
struct AppMigrationItemRow: View {
    let icon: MaterialDesignIcons
    let tint: Color
    let title: String
    let caption: String

    var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spaces.oneAndHalf) {
            MaterialDesignIconsImage(icon: icon, size: 22)
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.micro) {
                Text(title)
                    .font(DesignSystem.Font.body)
                Text(caption)
                    .font(DesignSystem.Font.footnote)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: .zero)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
        AppMigrationItemRow(
            icon: .serverNetworkIcon,
            tint: .haSuccessColor,
            title: "Servers and sign-ins",
            caption: "Stay signed in to every server."
        )
        AppMigrationItemRow(
            icon: .widgetsOutlineIcon,
            tint: .secondary,
            title: "Home Screen widgets",
            caption: "Add them again from the new app."
        )
    }
    .padding()
}
