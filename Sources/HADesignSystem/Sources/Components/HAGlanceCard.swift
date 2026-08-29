#if !os(watchOS)
import SwiftUI

/// A grid of small readings, several entities to a card. The SwiftUI counterpart of the frontend's
/// `hui-glance-card`.
public struct HAGlanceCard: View {
    private let title: String?
    private let items: [HAGlanceItem]
    private let columns: Int
    private let showsNames: Bool
    private let showsStates: Bool
    private let onTap: ((HAGlanceItem) -> Void)?

    /// - Parameter columns: How many cells to a row. The frontend defaults to the entity count,
    ///   capped at 4; a fixed default keeps the layout predictable here.
    public init(
        title: String? = nil,
        items: [HAGlanceItem],
        columns: Int = 4,
        showsNames: Bool = true,
        showsStates: Bool = true,
        onTap: ((HAGlanceItem) -> Void)? = nil
    ) {
        self.title = title
        self.items = items
        self.columns = columns
        self.showsNames = showsNames
        self.showsStates = showsStates
        self.onTap = onTap
    }

    public var body: some View {
        HACard(header: title) {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: DesignSystem.Spaces.one),
                    count: Swift.max(1, columns)
                ),
                spacing: DesignSystem.Spaces.two
            ) {
                ForEach(items) { item in
                    VStack(spacing: DesignSystem.Spaces.half) {
                        if showsNames {
                            Text(item.name)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if let icon = item.icon {
                            MaterialDesignIconsImage(icon: icon, size: 24)
                                .foregroundStyle(item.color)
                        }
                        if showsStates, let state = item.state {
                            Text(state)
                                .font(.system(size: 12))
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { onTap?(item) }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(DesignSystem.Spaces.two)
        }
    }
}

private let sampleGlanceItems = [
    HAGlanceItem(id: "1", name: "Kitchen", icon: .lightbulbOnIcon, color: .haWarningColor, state: "On"),
    HAGlanceItem(id: "2", name: "Hallway", icon: .lightbulbIcon, state: "Off"),
    HAGlanceItem(id: "3", name: "Porch", icon: .lightbulbIcon, state: "Off"),
    HAGlanceItem(id: "4", name: "Garage", icon: .garageIcon, state: "Closed"),
]

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAGlanceCard(title: "Lights", items: sampleGlanceItems)
        HAGlanceCard(items: sampleGlanceItems, columns: 2)
        HAGlanceCard(items: sampleGlanceItems, showsNames: false)
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAGlanceCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-glance-card" }
}

#endif
