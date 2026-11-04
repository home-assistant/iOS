#if !os(watchOS)
import HAIconic
import SwiftUI

/// The entity's own row at the top of a more-info dialog for a domain without a dedicated design:
/// icon, name, when it last changed, and the domain's control on the trailing edge. The SwiftUI
/// counterpart of the frontend's `state-card-content`, which `state-card-scene`,
/// `state-card-input_number`, `state-card-input_text` and `state-card-update` each fill.
///
/// Built on ``HAEntityRow``; what it adds is the relative time in the secondary line.
public struct HAMoreInfoStateCard<Trailing: View>: View {
    @Environment(\.locale) private var locale
    private let name: String
    private let icon: MaterialDesignIcons
    private let color: Color
    private let lastChanged: Date
    private let now: Date
    private let trailing: Trailing

    public init(
        name: String,
        icon: MaterialDesignIcons,
        color: Color = .haPrimary,
        lastChanged: Date,
        now: Date,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.name = name
        self.icon = icon
        self.color = color
        self.lastChanged = lastChanged
        self.now = now
        self.trailing = trailing()
    }

    private var lastChangedText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastChanged, relativeTo: now)
    }

    public var body: some View {
        HAEntityRow(name: name, icon: icon, color: color, secondary: lastChangedText) {
            trailing
        }
    }
}

#Preview {
    VStack {
        HAMoreInfoStateCard(
            name: "Romantic scene",
            icon: .paletteIcon,
            lastChanged: Date(timeIntervalSinceNow: -600),
            now: Date()
        ) {
            Button("Activate") {}
        }
        HAMoreInfoStateCard(
            name: "Box",
            icon: .rayVertexIcon,
            lastChanged: Date(timeIntervalSinceNow: -1200),
            now: Date()
        ) {
            Text("0 items")
        }
    }
    .padding()
}

extension HAMoreInfoStateCard: FrontendComponent {
    public static var frontendComponentName: String { "state-card-content" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
