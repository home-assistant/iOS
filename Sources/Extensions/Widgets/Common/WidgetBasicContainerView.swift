import AppIntents
import Shared
import SwiftUI
import WidgetKit

struct WidgetBasicContainerView: View {
    @Environment(\.widgetFamily) var family: WidgetFamily

    let emptyViewGenerator: () -> AnyView
    let contents: [WidgetBasicViewModel]

    init(emptyViewGenerator: @escaping () -> AnyView, contents: [WidgetBasicViewModel]) {
        self.emptyViewGenerator = emptyViewGenerator
        self.contents = contents
    }

    var body: some View {
        Group {
            if contents.isEmpty {
                emptyViewGenerator()
            } else {
                content(for: contents)
            }
        }
        // Whenever Apple allow apps to use material backgrounds we should update this
        .widgetBackground(Color.asset(Asset.Colors.primaryBackground))
    }

    @available(iOS 17.0, *)
    private func intent(for model: WidgetBasicViewModel) -> (any AppIntent)? {
        switch model.interactionType {
        case .widgetURL:
            return nil
        case let .appIntent(widgetIntentType):
            switch widgetIntentType {
            case .action:
                var intent = PerformAction()
                intent.action = IntentActionAppEntity(id: model.id, displayString: model.title)
                intent.hapticConfirmation = true
                return intent
            case let .script(id, serverId, name, showConfirmationNotification):
                let intent = ScriptAppIntent()
                intent.script = .init(
                    id: id,
                    serverId: serverId,
                    serverName: "", // not used in this context
                    displayString: name,
                    iconName: "" // not used in this context
                )
                intent.hapticConfirmation = true
                intent.showConfirmationNotification = showConfirmationNotification
                return intent
            }
        }
    }

    @ViewBuilder
    func content(for models: [WidgetBasicViewModel]) -> some View {
        let actionCount = models.count
        let columnCount = Self.columnCount(family: family, modelCount: actionCount)
        let rows = Array(columnify(count: columnCount, models: models))

        let sizeStyle: WidgetBasicSizeStyle = {
            if models.count == 1 {
                return .single
            }

            let compactBp = Self.compactSizeBreakpoint(for: family)

            let condensed = compactBp < actionCount
            let compactRowCount = compactBp / Self.columnCount(family: family, modelCount: compactBp)

            if condensed {
                return .condensed
            } else if rows.count < compactRowCount {
                return .expanded
            } else {
                return .regular
            }
        }()

        VStack(alignment: .leading, spacing: Spaces.one) {
            ForEach(rows, id: \.self) { column in
                HStack(spacing: Spaces.one) {
                    ForEach(column) { model in
                        if case let .widgetURL(url) = model.interactionType {
                            Link(destination: url.withWidgetAuthenticity()) {
                                WidgetBasicView(model: model, sizeStyle: sizeStyle)
                            }
                        } else {
                            if #available(iOS 17.0, *), let intent = intent(for: model) {
                                Button(intent: intent) {
                                    WidgetBasicView(model: model, sizeStyle: sizeStyle)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(models.count == 1 ? 0 : Spaces.one)
    }

    private func columnify(count: Int, models: [WidgetBasicViewModel]) -> AnyIterator<[WidgetBasicViewModel]> {
        var perActionIterator = models.makeIterator()
        return AnyIterator { () -> [WidgetBasicViewModel]? in
            let column = stride(from: 0, to: count, by: 1)
                .compactMap { _ in perActionIterator.next() }
            return column.isEmpty == false ? column : nil
        }
    }

    static func columnCount(family: WidgetFamily, modelCount: Int) -> Int {
        switch family {
        #if !targetEnvironment(macCatalyst) // no ventura SDK yet
        case .accessoryCircular, .accessoryInline, .accessoryRectangular: return 1
        #endif
        case .systemSmall: return 1
        case .systemMedium: return 2
        case .systemLarge:
            if modelCount <= 2 {
                // 2 'landscape' actions looks better than 2 'portrait'
                return 1
            } else {
                return 2
            }
        case .systemExtraLarge:
            if modelCount <= 4 {
                return 1
            } else if modelCount <= 15 {
                // note this is 15 and not 16 - divisibility by 3 here
                return 3
            } else {
                return 4
            }
        @unknown default: return 2
        }
    }

    /// More than this number: show compact (icon left, text right) version
    static func compactSizeBreakpoint(for family: WidgetFamily) -> Int {
        switch family {
        #if !targetEnvironment(macCatalyst) // no ventura SDK yet
        case .accessoryCircular,
             .accessoryInline,
             .accessoryRectangular:
            return 1
        #endif
        case .systemSmall: return 2
        case .systemMedium: return 4
        case .systemLarge: return 10
        case .systemExtraLarge: return 20
        @unknown default: return 8
        }
    }

    static func maximumCount(family: WidgetFamily) -> Int {
        switch family {
        #if !targetEnvironment(macCatalyst) // no ventura SDK yet
        case .accessoryCircular,
             .accessoryInline,
             .accessoryRectangular:
            return 1
        #endif
        case .systemSmall: return 2
        case .systemMedium: return 4
        case .systemLarge: return 10
        case .systemExtraLarge: return 20
        @unknown default: return 4
        }
    }

    // This is all widgets that are on the lock screen
    // Lock screen widgets are transparent and don't need a colored background
    private static var transparentFamilies: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            [.accessoryCircular, .accessoryRectangular]
        } else {
            []
        }
    }
}
