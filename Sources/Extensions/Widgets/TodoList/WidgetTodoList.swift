import Intents
import Shared
import SwiftUI
import WidgetKit
import AppIntents

@available(iOS 17, *)
struct WidgetTodoList: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetsKind.todoList.rawValue,
            provider: WidgetTodoListAppIntentTimelineProvider(),
        ) { timelineEntry in
            WidgetTodoListView(context: .init(
                title: timelineEntry.listTitle,
                items: timelineEntry.items.map({ item in
                    WidgetTodoListView.Context.Item(
                        id: item,
                        text: item
                    )
                }))
            )
            .frame(alignment: .topLeading)
            .widgetBackground(.primaryBackground)
        }
        .configurationDisplayName("To do list")
        .description("Check your lists and add items")
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        [.systemSmall, .systemMedium, .systemLarge]
    }
}

@available(iOS 17, *)
#Preview(as: .systemMedium, widget: {
    WidgetTodoList()
}, timeline: {
    let date = Date()
    WidgetTodoListEntry(date: date, listTitle: "Supermercado", items: [
        "Coca-cola",
        "Bread",
        "Eggs"
    ], family: .systemMedium)
})

struct WidgetTodoListView: View {

    struct Context {
        let title: String
        let items: [Item]

        struct Item {
            let id: String
            let text: String
        }
    }

    let context: Context
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: .zero) {
                    HStack {
                        Text(context.title)
                            .font(DesignSystem.Font.title3.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        HStack {
                            Image(systemSymbol: .arrowClockwiseCircle)
                                .foregroundStyle(.secondary)
                                .font(DesignSystem.Font.title)
                            Image(systemSymbol: .plusCircleFill)
                                .foregroundStyle(.haPrimary)
                                .font(DesignSystem.Font.title)
                        }
                        .offset(y: DesignSystem.Spaces.half)
                    }
                    VStack(alignment: .leading, spacing: .zero) {
                        ForEach(context.items, id: \.id) { item in
                            HStack {
                                Image(systemSymbol: .circle)
                                    .font(DesignSystem.Font.body)
                                    .foregroundStyle(.haPrimary)
                                Text(item.text)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .frame(height: 40)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(.logo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .padding(DesignSystem.Spaces.half)
            }
        }
        .widgetBackground(.primaryBackground)
    }
}

//#Preview {
//    WidgetTodoListView(context: .init(title: "List title", items: [
//        .init(id: "1", text: "Coca-cola"),
//        .init(id: "2", text: "Bread"),
//        .init(id: "3", text: "Eggs"),
//        .init(id: "4", text: "Toilet paper")
//    ]))
//}
