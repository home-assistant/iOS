import Foundation
import Shared
import SwiftUI

@available(iOS 17, *)
struct WidgetTodoListView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    private static let minuteFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute]
        formatter.unitsStyle = .full
        return formatter
    }()

    private static let namedRelativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return formatter
    }()

    private static let numericRelativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .numeric
        return formatter
    }()

    let serverId: String
    let listId: String
    let title: String
    let items: [TodoListItem]
    let isEmpty: Bool

    var body: some View {
        if isEmpty {
            emptyStateView
        } else {
            contentView
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            Image(systemSymbol: .checklistChecked)
                .font(.system(size: 32))
                .foregroundStyle(.haPrimary)
            Text(verbatim: L10n.Widgets.TodoList.title)
                .font(DesignSystem.Font.callout.bold())
            Text(verbatim: L10n.Widgets.TodoList.selectList)
                .font(DesignSystem.Font.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: .zero) {
            headerView
            itemsListView
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .bottomTrailing) {
            if widgetFamily != .systemSmall {
                Image(.logo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .padding(DesignSystem.Spaces.half)
            }
        }
    }

    private var headerView: some View {
        HStack {
            if widgetFamily == .systemSmall {
                Text(verbatim: title.first.map(String.init) ?? "")
                    .padding(DesignSystem.Spaces.one)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .clipShape(.circle)
                Spacer()
            } else {
                Text(title)
                    .font(DesignSystem.Font.title3.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            HStack(spacing: DesignSystem.Spaces.half) {
                Button(intent: TodoListRefreshAppIntent()) {
                    Image(systemSymbol: .arrowClockwiseCircle)
                        .foregroundStyle(.secondary)
                        .font(DesignSystem.Font.title)
                }
                .buttonStyle(.plain)
                if let addItemURL = AppConstants.todoListAddItemURL(listId: listId, serverId: serverId) {
                    Link(destination: addItemURL.withWidgetAuthenticity()) {
                        Image(systemSymbol: .plusCircleFill)
                            .foregroundStyle(.haPrimary)
                            .font(DesignSystem.Font.title)
                    }
                } else {
                    Image(systemSymbol: .plusCircleFill)
                        .foregroundStyle(.haPrimary)
                        .font(DesignSystem.Font.title)
                }
            }
        }
        .padding(.bottom, DesignSystem.Spaces.half)
    }

    private struct DueDisplay {
        let text: String
        let isPastDateOnly: Bool
    }

    // Internal for testing purposes
    func dueDisplay(for item: TodoListItem) -> DueDisplay? {
        guard let due = item.due else { return nil }
        let now = Date()
        if item.hasDueTime {
            // Check if the time difference is less than 1 hour
            let timeInterval = due.timeIntervalSince(now)
            let hourInSeconds: TimeInterval = 3600

            if abs(timeInterval) < hourInSeconds {
                // Calculate minutes for times within 1 hour
                let minutes = Int(round(timeInterval / 60))
                let text: String

                if minutes == 0 {
                    text = "Now"
                } else {
                    // Use DateComponentsFormatter for proper localization
                    let absMinutes = abs(minutes)
                    if let formattedMinutes = Self.minuteFormatter.string(from: TimeInterval(absMinutes * 60)) {
                        if minutes > 0 {
                            text = "In \(formattedMinutes)"
                        } else {
                            text = "\(capitalizeLeadingCharacter(in: formattedMinutes)) ago"
                        }
                    } else {
                        // Fallback if formatter fails
                        text = minutes > 0 ? "In \(absMinutes) minutes" : "\(absMinutes) minutes ago"
                    }
                }
                return DueDisplay(text: text, isPastDateOnly: false)
            }

            let text = Self.numericRelativeFormatter.localizedString(for: due, relativeTo: now)
            return DueDisplay(text: capitalizeLeadingCharacter(in: text), isPastDateOnly: false)
        }

        let calendar = Current.calendar()
        if calendar.isDateInToday(due) {
            return DueDisplay(text: L10n.Widgets.TodoList.DueDate.today, isPastDateOnly: false)
        }

        let dueAtNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: due) ?? due
        let nowAtNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        let text = Self.namedRelativeFormatter.localizedString(for: dueAtNoon, relativeTo: nowAtNoon)
        let isPastDateOnly = dueAtNoon < nowAtNoon
        return DueDisplay(text: capitalizeLeadingCharacter(in: text), isPastDateOnly: isPastDateOnly)
    }

    private func capitalizeLeadingCharacter(in text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased() + text.dropFirst()
    }

    private var widgetFamilyItemRowSpacing: CGFloat {
        switch widgetFamily {
        case .systemLarge, .systemExtraLarge:
            return DesignSystem.Spaces.one
        default:
            return DesignSystem.Spaces.micro
        }
    }

    private var itemsListView: some View {
        VStack(alignment: .leading, spacing: widgetFamilyItemRowSpacing) {
            if items.isEmpty {
                Text(verbatim: L10n.Widgets.TodoList.allDone)
                    .font(DesignSystem.Font.body)
                    .foregroundStyle(.secondary)
                    .frame(height: 40)
            } else {
                ForEach(items, id: \.uid) { item in
                    HStack(alignment: item.due != nil ? .top : .center) {
                        Button(intent: TodoItemCompleteAppIntent(
                            serverId: serverId,
                            listId: listId,
                            itemId: item.uid
                        )) {
                            Image(systemSymbol: .circle)
                                .font(DesignSystem.Font.body)
                                .foregroundStyle(.haPrimary)
                                .padding(.top, item.due != nil ? DesignSystem.Spaces.micro : 0)
                        }
                        .buttonStyle(.plain)
                        if let addItemURL = AppConstants.todoListAddItemURL(listId: listId, serverId: serverId) {
                            Link(destination: addItemURL.withWidgetAuthenticity()) {
                                VStack(alignment: .leading, spacing: .zero) {
                                    Text(item.summary)
                                        .font(DesignSystem.Font.callout)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    if let dueDisplay = dueDisplay(for: item) {
                                        HStack(spacing: DesignSystem.Spaces.half) {
                                            Image(uiImage: MaterialDesignIcons.clockTimeTwoIcon.image(
                                                ofSize: .init(width: 12, height: 12),
                                                color: dueDisplay.isPastDateOnly ? UIColor.orange : UIColor
                                                    .secondaryLabel
                                            ))
                                            Text(dueDisplay.text)
                                                .font(DesignSystem.Font.caption)
                                                .foregroundStyle(dueDisplay.isPastDateOnly ? Color.orange : .secondary)
                                                .lineLimit(1)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
