import AppIntents
import Shared
import SwiftUI
import WidgetKit

struct WidgetBasicContainerView: View {
    @Environment(\.widgetFamily) var family: WidgetFamily

    let emptyViewGenerator: () -> AnyView
    let contents: [WidgetBasicViewModel]
    let type: WidgetType

    init(emptyViewGenerator: @escaping () -> AnyView, contents: [WidgetBasicViewModel], type: WidgetType) {
        self.emptyViewGenerator = emptyViewGenerator
        self.contents = contents
        self.type = type
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

    @available(iOS 16.4, *)
    private func intent(for model: WidgetBasicViewModel) -> (any AppIntent)? {
        switch model.interactionType {
        case .widgetURL:
            return nil
        case let .appIntent(widgetIntentType):
            switch widgetIntentType {
            case .action:
                let intent = PerformAction()
                intent.action = IntentActionAppEntity(id: model.id, displayString: model.title)
                intent.hapticConfirmation = true
                return intent
            case let .script(id, entityId, serverId, name, showConfirmationNotification):
                let intent = ScriptAppIntent()
                intent.script = .init(
                    id: id,
                    entityId: entityId,
                    serverId: serverId,
                    serverName: "", // not used in this context
                    displayString: name,
                    iconName: "" // not used in this context
                )
                intent.hapticConfirmation = true
                intent.showConfirmationNotification = showConfirmationNotification
                return intent
            case .refresh:
                return ReloadWidgetsAppIntent()
            }
        }
    }

    @ViewBuilder
    func content(for models: [WidgetBasicViewModel]) -> some View {
        let modelsCount = models.count
        let columnCount = WidgetFamilySizes.columns(family: family, modelCount: modelsCount)
        let rows = Array(WidgetFamilySizes.rows(count: columnCount, models: models))
        basicView(
            rows: rows,
            sizeStyle: WidgetFamilySizes.sizeStyle(
                family: family,
                modelsCount: modelsCount,
                rowsCount: rows.count
            )
        )
    }

    @ViewBuilder
    private func basicView(rows: [[WidgetBasicViewModel]], sizeStyle: WidgetBasicSizeStyle) -> some View {
        let spacing = sizeStyle == .compressed ? .zero : Spaces.one
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(rows, id: \.self) { column in
                HStack(spacing: spacing) {
                    ForEach(column) { model in
                        if case let .widgetURL(url) = model.interactionType {
                            Link(destination: url.withWidgetAuthenticity()) {
                                if #available(iOS 18.0, *) {
                                    tintedWrapperView(model: model, sizeStyle: sizeStyle)
                                } else {
                                    normalView(model: model, sizeStyle: sizeStyle)
                                }
                            }
                        } else {
                            if #available(iOS 17.0, *), let intent = intent(for: model) {
                                Button(intent: intent) {
                                    tintedWrapperView(model: model, sizeStyle: sizeStyle)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding([.single, .compressed].contains(sizeStyle) ? 0 : Spaces.one)
    }

    private func normalView(model: WidgetBasicViewModel, sizeStyle: WidgetBasicSizeStyle) -> some View {
        switch type {
        case .button:
            return AnyView(WidgetBasicButtonView(
                model: model,
                sizeStyle: sizeStyle,
                tinted: false
            ))
        case .sensor:
            return AnyView(WidgetBasicSensorView(
                model: model,
                sizeStyle: sizeStyle,
                tinted: false
            ))
        }
    }

    @available(iOS 16.0, *)
    private func tintedWrapperView(model: WidgetBasicViewModel, sizeStyle: WidgetBasicSizeStyle) -> some View {
        switch type {
        case .button:
            return AnyView(WidgetBasicViewTintedWrapper(
                model: model,
                sizeStyle: sizeStyle,
                viewType: WidgetBasicButtonView.self
            ))
        case .sensor:
            return AnyView(WidgetBasicViewTintedWrapper(
                model: model,
                sizeStyle: sizeStyle,
                viewType: WidgetBasicSensorView.self
            ))
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

    enum WidgetType: String {
        case button
        case sensor
    }
}
