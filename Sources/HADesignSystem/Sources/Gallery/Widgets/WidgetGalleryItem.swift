#if !os(watchOS)
import HAIconic
import SwiftUI
import WidgetKit

/// Every widget the app ships, drawn from the design system's own components with mocked data.
///
/// One case per component rather than one per widget: the tile widgets — custom, scripts, open page,
/// commonly used — are all the same grid with different contents, so they are listed once and the
/// subtitle says which widgets share it.
public enum WidgetGalleryItem: String, CaseIterable, Identifiable {
    case actions
    case sensors
    case assist
    case calendar
    case todoList
    case energy
    case gauge
    case details

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .actions: "Actions"
        case .sensors: "Sensors"
        case .assist: "Assist"
        case .calendar: "Calendar"
        case .todoList: "To-do list"
        case .energy: "Energy"
        case .gauge: "Gauge"
        case .details: "Details"
        }
    }

    /// Which shipped widgets this component draws.
    public var subtitle: String {
        switch self {
        case .actions: "Custom, Scripts, Open page, Commonly used"
        case .sensors: "Sensors"
        case .assist: "Assist"
        case .calendar: "Calendar"
        case .todoList: "To-do list"
        case .energy: "Energy"
        case .gauge: "Gauge — its own drawing, not a mirrored watch complication"
        case .details: "Details — its own drawing, not a mirrored watch complication"
        }
    }

    public var families: [WidgetFamily] {
        switch self {
        case .actions: [.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryInline]
        case .sensors: [.systemSmall, .systemMedium, .systemLarge]
        case .assist: [.systemSmall, .systemMedium, .accessoryCircular]
        case .calendar: [.systemSmall, .systemMedium, .systemLarge]
        case .todoList: [.systemSmall, .systemMedium, .systemLarge]
        case .energy: [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        case .gauge: [.systemSmall, .accessoryCircular]
        case .details: [.accessoryRectangular, .accessoryInline]
        }
    }

    @ViewBuilder public func preview(for family: WidgetFamily) -> some View {
        switch self {
        case .actions:
            tileGrid(models: WidgetTileSampleData.actions(fitting: family), family: family, kind: .button)
        case .sensors:
            tileGrid(models: WidgetTileSampleData.sensors(fitting: family), family: family, kind: .sensor)
        case .assist:
            assist(family: family)
        case .calendar:
            calendar(family: family)
        case .todoList:
            todoList(family: family)
        case .energy:
            energy(family: family)
        case .gauge:
            gauge(family: family)
        case .details:
            WidgetDetailsContentView(
                upperText: "Living room",
                lowerText: "21.4 °C",
                detailsText: "Humidity 48%",
                family: family
            )
            .padding(DesignSystem.Spaces.one)
        }
    }

    private func tileGrid(
        models: [WidgetTileModel],
        family: WidgetFamily,
        kind: WidgetTileKind
    ) -> some View {
        WidgetTileContainerView(
            contents: models,
            family: family,
            kind: kind,
            serverName: "Home",
            emptyView: { AnyView(WidgetEmptyStateView(message: "Nothing configured yet")) },
            refreshControl: Self.refreshControl(for: family)
        )
    }

    /// The lock screen accessories have no room for a footer, so they get no reload control either.
    private static func refreshControl(for family: WidgetFamily) -> (() -> AnyView)? {
        guard !WidgetGalleryFamilyMetrics.isAccessory(family) else { return nil }
        return { AnyView(WidgetRefreshLabel(date: WidgetCalendarSampleData.referenceDate)) }
    }

    @ViewBuilder
    private func assist(family: WidgetFamily) -> some View {
        switch family {
        case .systemSmall:
            WidgetAssistSingleView(title: "Assist", subtitle: "Home Assistant")
        case .accessoryCircular:
            WidgetCircularIconView(icon: .messageProcessingOutlineIcon)
        default:
            tileGrid(
                models: Array(WidgetTileSampleData.assistPipelines.prefix(WidgetTileLayout.size(for: family))),
                family: family,
                kind: .button
            )
        }
    }

    private func calendar(family: WidgetFamily) -> some View {
        WidgetCalendarContentView(
            referenceDate: WidgetCalendarSampleData.referenceDate,
            events: Array(WidgetCalendarSampleData.events.prefix(WidgetTileLayout.calendarSize(for: family))),
            calendarCount: 3,
            showsCalendarName: family != .systemSmall,
            calendar: WidgetCalendarSampleData.calendar,
            family: family,
            strings: .preview,
            refreshControl: { AnyView(WidgetRefreshLabel(date: WidgetCalendarSampleData.referenceDate)) }
        )
        .padding(DesignSystem.Spaces.two)
    }

    @ViewBuilder
    private func todoList(family: WidgetFamily) -> some View {
        if #available(iOS 17, *) {
            WidgetTodoListContentView(
                title: "Groceries",
                items: Array(Self.todoItems.prefix(WidgetTileLayout.todoListSize(for: family))),
                isConfigured: true,
                family: family,
                strings: .preview
            )
            .padding(DesignSystem.Spaces.two)
        }
    }

    private static let todoItems: [WidgetTodoItemModel] = [
        .init(id: "todo-0", summary: "Coffee beans"),
        .init(id: "todo-1", summary: "Book a table", dueText: "Tomorrow"),
        .init(id: "todo-2", summary: "Water the plants", dueText: "Yesterday", isOverdue: true),
        .init(id: "todo-3", summary: "Replace the filter", dueText: "Next week"),
        .init(id: "todo-4", summary: "Call the plumber"),
        .init(id: "todo-5", summary: "Pay the electricity bill", dueText: "Today"),
    ]

    @ViewBuilder
    private func energy(family: WidgetFamily) -> some View {
        if #available(iOS 17, *) {
            switch family {
            case .accessoryCircular:
                WidgetEnergyAccessoryCircularContentView(stat: WidgetEnergySampleData.stats.first)
            case .accessoryRectangular:
                WidgetEnergyAccessoryRectangularContentView(
                    stats: WidgetEnergySampleData.stats,
                    periodTitle: "Today",
                    emptyText: "No energy data"
                )
                .padding(DesignSystem.Spaces.one)
            case .accessoryInline:
                WidgetEnergyAccessoryInlineContentView(
                    stats: WidgetEnergySampleData.stats,
                    emptyText: "No energy data"
                )
            case .systemSmall:
                WidgetEnergySmallContentView(
                    stats: WidgetEnergySampleData.stats,
                    periodTitle: "Today",
                    date: WidgetEnergySampleData.dayStart
                )
            default:
                WidgetEnergyMediumContentView(
                    stats: WidgetEnergySampleData.stats,
                    costText: "€1.42",
                    periodTitle: "Today",
                    date: WidgetEnergySampleData.dayStart,
                    chartPoints: WidgetEnergySampleData.chartPoints,
                    periodRange: WidgetEnergySampleData.dayRange
                )
            }
        }
    }

    @ViewBuilder
    private func gauge(family: WidgetFamily) -> some View {
        if #available(iOS 17, *) {
            WidgetGaugeContentView(
                gaugeType: .normal,
                value: 0.67,
                valueLabel: "67%",
                min: "0",
                max: "100",
                family: family
            )
        }
    }
}
#endif
