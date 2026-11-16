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
            Image(uiImage: icon.image(ofSize: CGSize(width: 24, height: 24), color: UIColor(tint)))
                .frame(width: 24, height: 24)
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
            icon: .watchVariantIcon,
            tint: .haSuccessColor,
            title: "Watch, CarPlay and widget setup",
            caption: "Configured items and complications."
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
