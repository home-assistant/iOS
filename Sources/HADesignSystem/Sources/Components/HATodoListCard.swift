#if !os(watchOS)
import SFSafeSymbols
import SwiftUI

/// A to-do list on a card, completed items struck through under the rest. The SwiftUI counterpart of
/// the frontend's `hui-todo-list-card`.
public struct HATodoListCard: View {
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    private let title: String?
    private let items: [HATodoItem]
    private let hidesCompleted: Bool
    private let onToggle: ((HATodoItem) -> Void)?

    public init(
        title: String? = nil,
        items: [HATodoItem],
        hidesCompleted: Bool = false,
        onToggle: ((HATodoItem) -> Void)? = nil
    ) {
        self.title = title
        self.items = items
        self.hidesCompleted = hidesCompleted
        self.onToggle = onToggle
    }

    /// Outstanding first, then the done ones — the frontend groups them the same way, so finishing
    /// something moves it out of the way rather than leaving a gap in the list.
    private var orderedItems: [HATodoItem] {
        let outstanding = items.filter { !$0.isCompleted }
        return hidesCompleted ? outstanding : outstanding + items.filter(\.isCompleted)
    }

    public var body: some View {
        HACard(header: title) {
            VStack(spacing: .zero) {
                ForEach(orderedItems) { item in
                    HStack(alignment: .top, spacing: DesignSystem.Spaces.one) {
                        Image(systemSymbol: item.isCompleted ? .checkmarkCircleFill : .circle)
                            .foregroundStyle(item.isCompleted ? Color.haPrimary : .secondary)
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.micro) {
                            Text(item.summary)
                                .font(DesignSystem.Font.body)
                                .strikethrough(item.isCompleted)
                                .foregroundStyle(item.isCompleted ? .secondary : Color(uiColor: .label))
                            if let description = item.description {
                                Text(description)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            if let dueDate = item.dueDate {
                                // Formatted in the environment's zone: a due date stored at midnight UTC is a
                                // different calendar day either side of it, so the process zone
                                // would show the wrong day and make snapshots machine-dependent.
                                Text(dueDate.formatted(
                                    Date.FormatStyle(locale: locale, timeZone: timeZone)
                                        .day().month(.abbreviated)
                                ))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: .zero)
                    }
                    .padding(.vertical, DesignSystem.Spaces.one)
                    .contentShape(Rectangle())
                    .onTapGesture { onToggle?(item) }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(item.isCompleted ? .isSelected : [])
                    .accessibilityAddTraits(onToggle == nil ? [] : .isButton)
                }
            }
            .padding(.horizontal, DesignSystem.Spaces.two)
            .padding(.bottom, DesignSystem.Spaces.two)
        }
    }
}

/// 2026-09-01, pinned so the due date records the same way every run.
private let sampleDueDate = Date(timeIntervalSince1970: 1_788_220_800)

private let sampleTodoItems = [
    HATodoItem(id: "1", summary: "Buy milk", dueDate: sampleDueDate),
    HATodoItem(id: "2", summary: "Change the filter", description: "Under the sink"),
    HATodoItem(id: "3", summary: "Water the plants", isCompleted: true),
]

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HATodoListCard(title: "Shopping", items: sampleTodoItems)
        HATodoListCard(items: sampleTodoItems, hidesCompleted: true)
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HATodoListCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-todo-list-card" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
