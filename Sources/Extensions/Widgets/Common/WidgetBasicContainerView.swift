import AppIntents
import Shared
import SwiftUI
import WidgetKit

struct WidgetBasicContainerView: View {
    @Environment(\.widgetFamily) var family: WidgetFamily

    let emptyViewGenerator: () -> AnyView
    let contents: [WidgetBasicViewModel]
    let type: WidgetType
    let showLastUpdate: Bool

    init(
        emptyViewGenerator: @escaping () -> AnyView,
        contents: [WidgetBasicViewModel],
        type: WidgetType,
        showLastUpdate: Bool = false
    ) {
        self.emptyViewGenerator = emptyViewGenerator
        self.contents = contents
        self.type = type
        self.showLastUpdate = showLastUpdate
    }

    var body: some View {
        WidgetBasicContainerWrapperView(
            emptyViewGenerator: emptyViewGenerator,
            contents: contents,
            type: type,
            showLastUpdate: showLastUpdate,
            family: family
        )
    }
}

/// This wrapper only exists so it can be snapshot tested with the proper family size which is not possible with the
/// `WidgetBasicContainerView` and the environment variable
struct WidgetBasicContainerWrapperView: View {
    let emptyViewGenerator: () -> AnyView
    let contents: [WidgetBasicViewModel]
    let type: WidgetType
    let showLastUpdate: Bool
    let family: WidgetFamily

    init(
        emptyViewGenerator: @escaping () -> AnyView,
        contents: [WidgetBasicViewModel],
        type: WidgetType,
        showLastUpdate: Bool = false,
        family: WidgetFamily
    ) {
        self.emptyViewGenerator = emptyViewGenerator
        self.contents = contents
        self.type = type
        self.showLastUpdate = showLastUpdate
        self.family = family
    }

    var body: some View {
        VStack {
            if contents.isEmpty {
                emptyViewGenerator()
            } else {
                content(for: Array(contents.prefix(WidgetFamilySizes.size(for: family))))
            }
            if showLastUpdate, !contents.isEmpty {
                Group {
                    Text("\(L10n.Widgets.Custom.ShowUpdateTime.title) ") + Text(Date.now, style: .time)
                }
                .font(.system(size: 10).bold())
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.bottom, Spaces.half)
                .opacity(0.5)
            }
        }
        // Whenever Apple allow apps to use material backgrounds we should update this
        .widgetBackground(Color.asset(Asset.Colors.primaryBackground))
    }

    @ViewBuilder
    func content(for models: [WidgetBasicViewModel]) -> some View {
        let modelsCount = models.count
        let columnCount = WidgetFamilySizes.columns(family: family, modelCount: modelsCount)
        let rows = Array(WidgetFamilySizes.rows(count: columnCount, models: models))
        WidgetBasicView(
            type: type,
            rows: rows,
            sizeStyle: WidgetFamilySizes.sizeStyle(
                family: family,
                modelsCount: modelsCount,
                rowsCount: rows.count
            )
        )
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
