import SwiftUI
import Shared
import WidgetKit

enum WidgetBasicSizeStyle {
    case single
    case multiple(expanded: Bool, condensed: Bool)
}

protocol WidgetBasicEmptyView: View {
    init()
}

struct WidgetBasicModel: Identifiable, Hashable {
    init(
        id: String,
        title: String,
        widgetLinkURL: URL,
        icon: String,
        textColor: Color = Color.black,
        iconColor: Color = Color.black,
        backgroundColor: Color = Color.white
    ) {
        self.id = id
        self.title = title
        self.widgetLinkURL = widgetLinkURL
        self.textColor = textColor
        self.icon = icon
        self.iconColor = iconColor
        self.backgroundColor = backgroundColor
    }

    var id: String

    var title: String
    var widgetLinkURL: URL

    var icon: String

    var backgroundColor: Color
    var textColor: Color
    var iconColor: Color
}

struct WidgetBasicContainerView: View {
    @SwiftUI.Environment(\.widgetFamily) var family: WidgetFamily
    @SwiftUI.Environment(\.pixelLength) var pixelLength: CGFloat

    let emptyViewGenerator: () -> AnyView
    let contents: [WidgetBasicModel]

    init(emptyViewGenerator: @escaping () -> AnyView, contents: [WidgetBasicModel]) {
        self.emptyViewGenerator = emptyViewGenerator
        self.contents = contents
    }

    var body: some View {
        switch contents.count {
        case 0: emptyViewGenerator()
        case 1: singleView(for: contents.first!)
        default: multiView(for: contents)
        }
    }

    func singleView(for model: WidgetBasicModel) -> some View {
        WidgetBasicView(model: model, sizeStyle: .single)
            .widgetURL(model.widgetLinkURL)
    }

    @ViewBuilder
    func multiView(for models: [WidgetBasicModel]) -> some View {
        let actionCount = models.count
        let columnCount = Self.columnCount(family: family, modelCount: actionCount)
        let rows = Array(columnify(count: columnCount, models: models))
        let maximumRowCount = Self.maximumCount(family: family) / columnCount
        let sizeStyle: WidgetBasicSizeStyle = .multiple(
            expanded: rows.count < maximumRowCount,
            condensed: Self.compactSizeBreakpoint(for: family) < actionCount
        )

        VStack(alignment: .leading, spacing: pixelLength) {
            ForEach(rows, id: \.self) { column in
                HStack(spacing: pixelLength) {
                    ForEach(column) { model in
                        Link(destination: model.widgetLinkURL) {
                            WidgetBasicView(model: model, sizeStyle: sizeStyle)
                        }
                    }
                }
            }
        }
        .background(Color.black)
    }

    private func columnify(count: Int, models: [WidgetBasicModel]) -> AnyIterator<[WidgetBasicModel]> {
        var perActionIterator = models.makeIterator()
        return AnyIterator { () -> [WidgetBasicModel]? in
            let column = stride(from: 0, to: count, by: 1)
                .compactMap { _ in perActionIterator.next() }
            return column.isEmpty == false ? column : nil
        }
    }

    static func columnCount(family: WidgetFamily, modelCount: Int) -> Int {
        switch family {
        case .systemSmall: return 1
        case .systemMedium: return 2
        case .systemLarge:
            if modelCount <= 2 {
                // 2 'landscape' actions looks better than 2 'portrait'
                return 1
            } else {
                return 2
            }
#if compiler(>=5.5) && !targetEnvironment(macCatalyst)
        case .systemExtraLarge:
            if actionCount <= 4 {
                return 1
            } else if actionCount <= 15 {
                // note this is 15 and not 16 - divisibility by 3 here
                return 3
            } else {
                return 4
            }
#endif
        @unknown default: return 2
        }
    }

    /// more than this number: show compact (icon left, text right) version
    static func compactSizeBreakpoint(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 1
        case .systemMedium: return 4
        case .systemLarge: return 8
#if compiler(>=5.5) && !targetEnvironment(macCatalyst)
        case .systemExtraLarge: return 16
#endif
        @unknown default: return 8
        }
    }

    static func maximumCount(family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 1
        case .systemMedium: return 8
        case .systemLarge: return 16
#if compiler(>=5.5) && !targetEnvironment(macCatalyst)
        case .systemExtraLarge: return 32
#endif
        @unknown default: return 8
        }
    }
}
