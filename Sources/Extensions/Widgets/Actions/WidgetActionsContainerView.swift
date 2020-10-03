import WidgetKit
import SwiftUI
import Shared

struct WidgetActionsContainerView: View {
    var entry: WidgetActionsEntry
    @SwiftUI.Environment(\.widgetFamily) var family: WidgetFamily

    init(entry: WidgetActionsEntry) {
        self.entry = entry
    }

    var body: some View {
        switch entry.actions.count {
        case 0: emptyView()
        case 1: singleView(for: entry.actions.first!)
        default: multiView(for: entry.actions)
        }
    }

    func emptyView() -> some View {
        WidgetActionsEmptyView()
    }

    func singleView(for action: Action) -> some View {
        WidgetActionsActionView(action: action, sizeStyle: .single)
            .widgetURL(action.widgetLinkURL)
    }

    @ViewBuilder
    func multiView(for actions: [Action]) -> some View {
        let columnCount = Self.columnCount(family: family, actionCount: actions.count)
        let rows = Array(columnify(count: columnCount, actions: actions))
        let maximumRowCount = Self.maximumCount(family: family) / columnCount
        let sizeStyle: WidgetActionsActionView.SizeStyle = .multiple(expanded: rows.count < maximumRowCount)

        VStack(alignment: .leading, spacing: 1) {
            ForEach(rows, id: \.self) { column in
                HStack(spacing: 1) {
                    ForEach(column, id: \.ID) { action in
                        Link(destination: action.widgetLinkURL) {
                            WidgetActionsActionView(action: action, sizeStyle: sizeStyle)
                        }
                    }
                }
            }
        }
        .background(Color.black)
    }

    private func columnify(count: Int, actions: [Action]) -> AnyIterator<[Action]> {
        var perActionIterator = actions.makeIterator()
        return AnyIterator { () -> [Action]? in
            let column = stride(from: 0, to: count, by: 1)
                .compactMap { _ in perActionIterator.next() }
            return column.isEmpty == false ? column : nil
        }
    }

    static func columnCount(family: WidgetFamily, actionCount: Int) -> Int {
        switch family {
        case .systemSmall: return 1
        case .systemMedium: return 2
        case .systemLarge:
            if actionCount <= 2 {
                // 2 'landscape' actions looks better than 2 'portrait'
                return 1
            } else {
                return 2
            }
        @unknown default: return 2
        }
    }

    static func maximumCount(family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 1
        case .systemMedium: return 4
        case .systemLarge: return 8
        @unknown default: return 8
        }
    }
}

#if DEBUG
struct WidgetActionsContainerView_Previews: PreviewProvider {
    static func action() -> Action {
        with(Action()) {
            $0.Text = [
                "Butter Fingers",
                "Three Musketeers",
                "Milky Way",
                "Almond Joy",
                "Hershey's",
                "Snickers",
                "Crunch",
                "Reese's Pieces",
                "PayDay",
                "Twix",
                "Mr. Goodbar",
                "Kit Kat",
                "M&M's"
            ].randomElement()!
        }
    }

    static var previews: some View {
        WidgetActionsContainerView(entry: .init(actions: [
            action(),
            action()
        ]))
        .previewContext(WidgetPreviewContext(family: .systemMedium))

        WidgetActionsContainerView(entry: .init(actions: [
            action(),
            action(),
            action()
        ]))
        .previewContext(WidgetPreviewContext(family: .systemMedium))

//        WidgetActionsContainerView(entry: .init(actions: [
//            action(),
//            action(),
//            action(),
//            action()
//        ]))
//        .previewContext(WidgetPreviewContext(family: .systemMedium))

        WidgetActionsContainerView(entry: .init(actions: [
            action(),
            action()
        ]))
        .previewContext(WidgetPreviewContext(family: .systemLarge))

        WidgetActionsContainerView(entry: .init(actions: [
            action(),
            action(),
            action()
        ]))
        .previewContext(WidgetPreviewContext(family: .systemLarge))

        WidgetActionsContainerView(entry: .init(actions: [
            action(),
            action(),
            action(),
            action(),
            action()
        ]))
        .previewContext(WidgetPreviewContext(family: .systemLarge))

        WidgetActionsContainerView(entry: .init(actions: [
            action(),
            action(),
            action(),
            action(),
            action(),
            action(),
            action(),
            action()
        ]))
        .previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
#endif
