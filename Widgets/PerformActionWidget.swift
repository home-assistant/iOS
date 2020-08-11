import WidgetKit
import SwiftUI
import Shared
import Intents

struct PerformActionWidgetProvider: IntentTimelineProvider {

    typealias Intent = PerformActionIntent

    // start beta 3 compatibility code for github actions
    // swiftlint:disable line_length
    typealias Entry = PerformActionEntry

    func snapshot(for configuration: PerformActionIntent, with context: Context, completion: @escaping (Self.Entry) -> Void) {
        getSnapshot(for: configuration, in: context, completion: completion)
    }

    func timeline(for configuration: PerformActionIntent, with context: Context, completion: @escaping (Timeline<Self.Entry>) -> Void) {
        getTimeline(for: configuration, in: context, completion: completion)
    }
    // swiftlint:enable line_length
    // end beta 3 compatibility code

    func placeholder(in context: Self.Context) -> Self.Entry {
        PerformActionEntry(display: .action(with(Action()) {
            $0.Text = "Example"
        }))
    }

    func getSnapshot(for configuration: Intent, in context: Context, completion: @escaping (Entry) -> Void) {
        if let action = configuration.actions?.actionModel {
            completion(.init(display: .action(action)))
        } else {
            completion(.init(display: .empty))
        }
    }

    func getTimeline(for configuration: Intent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        var entries: [PerformActionEntry] = []

        if let action = configuration.actions?.actionModel {
            entries.append(.init(display: .action(action)))
        } else {
            entries.append(.init(display: .empty))
        }

        completion(.init(entries: [

        ], policy: .never))
    }
}

struct PerformActionEntry: TimelineEntry {
    var date: Date = Date()

    enum Display {
        case empty
        case action(Action)
    }

    var display: Display

    var icon: UIImage {
        let iconName: String

        switch display {
        case .action(let action): iconName = action.IconName
        case .empty: iconName = ""
        }

        return MaterialDesignIcons(named: iconName)
                .image(ofSize: CGSize(width: 96, height: 96), color: nil)
    }

    var backgroundColor: Color {
        switch display {
        case .action(let action):
            if let uiColor = try? UIColor(rgba_throws: action.BackgroundColor) {
                return Color(uiColor)
            } else {
                return .clear
            }
        case .empty:
            return .clear
        }
    }

    var text: String {
        switch display {
        case .action(let action): return action.Text
        case .empty: return "Empty"
        }
    }

    var textColor: Color {
        switch display {
        case .action(let action):
            if let uiColor = try? UIColor(rgba_throws: action.TextColor) {
                return Color(uiColor)
            } else {
                return .clear
            }
        case .empty:
            return .clear
        }
    }

    var iconColor: Color {
        switch display {
        case .action(let action):
            if let uiColor = try? UIColor(rgba_throws: action.IconColor) {
                return Color(uiColor)
            } else {
                return .clear
            }
        case .empty:
            return .white
        }
    }
}

struct PerformActionView: View {
    var entry: PerformActionEntry

    init(entry: PerformActionEntry) {
        self.entry = entry

        MaterialDesignIcons.register()
    }

    var body: some View {
        ZStack(alignment: .init(horizontal: .leading, vertical: .center)) {
            entry.backgroundColor
            VStack(alignment: .leading) {
                Image(uiImage: entry.icon)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundColor(entry.iconColor)
                    .frame(maxWidth: 42, maxHeight: 42, alignment: .leading)

                Spacer()

                Text(entry.text)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(entry.textColor)
            }
            .padding()
        }
    }
}

struct PerformActionWidget: Widget {
    static let kind = "PerformAction"

    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: Self.kind,
            intent: PerformActionIntent.self,
            provider: PerformActionWidgetProvider(),
            content: { PerformActionView(entry: $0) }
        )
        .configurationDisplayName("Perform Action")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#if DEBUG
struct PerformActionWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PerformActionView(entry: .init(display: .action(with(Action()) {
                $0.Text = "Action Text"
            })))
            PerformActionView(entry: .init(display: .action(with(Action()) {
                $0.Text = "Longer Action Text That Wraps Yeah"
            })))
        }
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
#endif
