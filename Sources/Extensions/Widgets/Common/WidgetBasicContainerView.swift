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

@available(iOS 18, *)
struct WidgetBasicContainerView_Previews: PreviewProvider {
    struct WidgetBasicContainerViewPreviewData {
        let modelsCount: Int
        let withSubtitle: Bool
        let withIconBackgroundColor: Bool
    }

    static var previews: some View {
        WidgetBasicContainerView_Previews.systemSmallConfigurations.previews()
        WidgetBasicContainerView_Previews.systemMediumConfigurations.previews()
        WidgetBasicContainerView_Previews.systemLargeConfigurations.previews()
    }

    static var systemSmallConfigurations: SnapshottablePreviewConfigurations<WidgetBasicContainerViewPreviewData> =
        .init(
            configurations: Self.configurations(for: .systemSmall)
        ) { previewData in
            widgetBasicContainerView(
                modelsCount: previewData.modelsCount,
                withSubtitle: previewData.withSubtitle,
                withIconBackgroundColor: previewData.withIconBackgroundColor,
                familySize: .systemSmall
            )
            .previewContext(WidgetPreviewContext(family: WidgetFamily.systemSmall))
        }

    static var systemMediumConfigurations: SnapshottablePreviewConfigurations<WidgetBasicContainerViewPreviewData> =
        .init(
            configurations: Self.configurations(for: .systemMedium)
        ) { previewData in
            widgetBasicContainerView(
                modelsCount: previewData.modelsCount,
                withSubtitle: previewData.withSubtitle,
                withIconBackgroundColor: previewData.withIconBackgroundColor,
                familySize: .systemMedium
            )
            .previewContext(WidgetPreviewContext(family: WidgetFamily.systemMedium))
        }

    static var systemLargeConfigurations: SnapshottablePreviewConfigurations<WidgetBasicContainerViewPreviewData> =
        .init(
            configurations: Self.configurations(for: .systemLarge)
        ) { previewData in
            widgetBasicContainerView(
                modelsCount: previewData.modelsCount,
                withSubtitle: previewData.withSubtitle,
                withIconBackgroundColor: previewData.withIconBackgroundColor,
                familySize: .systemLarge
            )
            .previewContext(WidgetPreviewContext(family: WidgetFamily.systemLarge))
        }

    private static func maxTiles(for familySize: WidgetFamily) -> Int {
        switch familySize {
        case .systemSmall: 3
        case .systemMedium: 6
        case .systemLarge: 12
        default: 12
        }
    }

    private static func configurations(for familySize: WidgetFamily)
        -> [
            SnapshottablePreviewConfigurations<WidgetBasicContainerViewPreviewData>
                .Configuration<WidgetBasicContainerViewPreviewData>
        ] {
        (1 ... maxTiles(for: familySize))
            .flatMap { maxTiles in
                [
                    .init(
                        item: .init(
                            modelsCount: maxTiles,
                            withSubtitle: true,
                            withIconBackgroundColor: true
                        ),
                        name: "withSubtitleWithIconBackground-\(familySize.description)-\(maxTiles)_tiles"
                    ),
                    .init(
                        item: .init(
                            modelsCount: maxTiles,
                            withSubtitle: true,
                            withIconBackgroundColor: false
                        ),
                        name: "withSubtitleWithoutIconBackground-\(familySize.description)-\(maxTiles)_tiles"
                    ),
                    .init(
                        item: .init(
                            modelsCount: maxTiles,
                            withSubtitle: false,
                            withIconBackgroundColor: true
                        ),
                        name: "withoutSubtitleWithIconBackground-\(familySize.description)-\(maxTiles)_tiles"
                    ),
                    .init(
                        item: .init(
                            modelsCount: maxTiles,
                            withSubtitle: false,
                            withIconBackgroundColor: false
                        ),
                        name: "withoutSubtitleWithoutIconBackground-\(familySize.description)-\(maxTiles)_tiles"
                    ),
                ]
            }
    }

    private static func widgetBasicContainerView(
        modelsCount: Int,
        withSubtitle: Bool,
        withIconBackgroundColor: Bool,
        familySize: WidgetFamily
    ) -> some View {
        WidgetBasicContainerWrapperView(
            emptyViewGenerator: {
                AnyView(EmptyView())
            },
            contents: models(
                count: modelsCount,
                withSubtitle: withSubtitle,
                withIconBackgroundColor: withIconBackgroundColor
            ),
            type: .custom,
            family: familySize
        )
    }

    private static func models(
        count: Int,
        withSubtitle: Bool,
        withIconBackgroundColor: Bool
    ) -> [WidgetBasicViewModel] {
        (0 ..< count).map { index in
            WidgetBasicViewModel(
                id: "\(index)",
                title: "Title \(index)",
                subtitle: withSubtitle ? "Subtitle \(index)" : nil,
                interactionType: .appIntent(.refresh),
                icon: .abTestingIcon,
                showIconBackground: withIconBackgroundColor
            )
        }
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
