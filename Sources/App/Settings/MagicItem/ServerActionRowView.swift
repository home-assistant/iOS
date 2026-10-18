import SFSafeSymbols
import Shared
import SwiftUI

/// One action in `ServerActionPickerList`: the server's icon for it, its name, and the
/// `domain.service` pair underneath so two actions sharing a name stay tellable apart.
struct ServerActionRowView: View {
    let action: IntentActionDefinition
    let isSelected: Bool

    private let iconSize = CGSize(width: 24, height: 24)

    var body: some View {
        HStack(spacing: DesignSystem.Spaces.two) {
            Image(uiImage: icon)
                .frame(width: iconSize.width, height: iconSize.height)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: action.displayName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(Color.primary)
                Text(verbatim: action.actionId)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(DesignSystem.Font.footnote)
                    .foregroundStyle(Color.secondary)
            }
            if isSelected {
                Image(systemSymbol: .checkmark)
                    .foregroundStyle(.haPrimary)
            }
        }
    }

    /// The frontend's own icon for the action, falling back to the bolt the "Perform action" App
    /// Intent shows for an action the server describes without one.
    private var icon: UIImage {
        MaterialDesignIcons(
            serversideValueNamed: action.icon.orEmpty,
            fallback: .flashIcon
        ).image(
            ofSize: iconSize,
            color: UIColor(Color.haPrimary)
        )
    }
}

#Preview {
    List {
        ServerActionRowView(
            action: .init(
                domain: "light",
                service: "turn_on",
                name: "Turn on",
                actionDescription: nil,
                icon: "mdi:lightbulb-on"
            ),
            isSelected: true
        )
        ServerActionRowView(
            action: .init(domain: "script", service: "reload", name: "Reload", actionDescription: nil),
            isSelected: false
        )
    }
}
