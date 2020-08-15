import WidgetKit
import SwiftUI
import Shared

struct WidgetActionsContainerView: View {
    var entry: WidgetActionsEntry
    @SwiftUI.Environment(\.widgetFamily) var family: WidgetFamily

    init(entry: WidgetActionsEntry) {
        self.entry = entry

        MaterialDesignIcons.register()
    }

    private func columnify(count: Int, actions: [Action]) -> AnyIterator<[Action]> {
        var perActionIterator = actions.makeIterator()
        return AnyIterator { () -> [Action]? in
            var column = [Action]()

            stride: for _ in stride(from: 0, to: count, by: 1) {
                if let next = perActionIterator.next() {
                    column.append(next)
                } else {
                    break stride
                }
            }

            if column.isEmpty {
                return nil
            }

            return column
        }
    }

    private static func columnCount(family: WidgetFamily, actionCount: Int) -> Int {
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

    var body: some View {
        let columns = columnify(
            count: Self.columnCount(family: family, actionCount: entry.actions.count),
            actions: entry.actions
        )

        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(columns), id: \.self) { column in
                HStack(spacing: 1) {
                    ForEach(column, id: \.ID) { action in
                        WidgetActionsActionView(action: action)
                    }
                }
            }
        }
        .background(Color.black)
    }
}

struct WidgetActionsActionView: View {
    let action: Action

    init(action: Action) {
        self.action = action
    }

    var icon: UIImage {
        MaterialDesignIcons(named: action.IconName)
            .image(ofSize: CGSize(width: 96, height: 96), color: nil)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Color(hex: action.BackgroundColor)
            Link(destination: URL(string: "http://\(action.IconName)")!) {
                VStack(alignment: .leading) {
                    Image(uiImage: icon)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundColor(.init(hex: action.IconColor))
                        .frame(
                            minWidth: 18,
                            maxWidth: 42,
                            minHeight: 18,
                            maxHeight: 42,
                            alignment: .leading
                        )

                    Spacer()

                    Text(verbatim: action.Text)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: false)
                        .foregroundColor(.init(hex: action.TextColor))
                }
            }
            .padding()
        }
    }
}
