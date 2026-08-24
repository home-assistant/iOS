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
    let showServerName: Bool
    let serverName: String?
    let widgetKind: WidgetsKind

    init(
        emptyViewGenerator: @escaping () -> AnyView,
        contents: [WidgetBasicViewModel],
        type: WidgetType,
        showLastUpdate: Bool = false,
        showServerName: Bool = false,
        serverName: String? = nil,
        widgetKind: WidgetsKind
    ) {
        self.emptyViewGenerator = emptyViewGenerator
        self.contents = contents
        self.type = type
        self.showLastUpdate = showLastUpdate
        self.showServerName = showServerName
        self.serverName = serverName
        self.widgetKind = widgetKind
    }

    var body: some View {
        WidgetBasicContainerWrapperView(
            emptyViewGenerator: emptyViewGenerator,
            contents: contents,
            type: type,
            showLastUpdate: showLastUpdate,
            showServerName: showServerName,
            serverName: serverName,
            widgetKind: widgetKind,
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
            #if !WIDGET_EXTENSION
                .environment(\.widgetFamily, .systemSmall)
            #endif
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
            #if !WIDGET_EXTENSION
                .environment(\.widgetFamily, .systemMedium)
            #endif
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
            #if !WIDGET_EXTENSION
                .environment(\.widgetFamily, .systemLarge)
            #endif
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
                        name: previewName(
                            "withSubtitleWithIconBackground",
                            widgetFamily: familySize,
                            tilesCount: maxTiles
                        )
                    ),
                    .init(
                        item: .init(
                            modelsCount: maxTiles,
                            withSubtitle: true,
                            withIconBackgroundColor: false
                        ),
                        name: previewName(
                            "withSubtitleWithoutIconBackground",
                            widgetFamily: familySize,
                            tilesCount: maxTiles
                        )
                    ),
                    .init(
                        item: .init(
                            modelsCount: maxTiles,
                            withSubtitle: false,
                            withIconBackgroundColor: true
                        ),
                        name: previewName(
                            "withoutSubtitleWithIconBackground",
                            widgetFamily: familySize,
                            tilesCount: maxTiles
                        )
                    ),
                    .init(
                        item: .init(
                            modelsCount: maxTiles,
                            withSubtitle: false,
                            withIconBackgroundColor: false
                        ),
                        name: previewName(
                            "withoutSubtitleWithoutIconBackground",
                            widgetFamily: familySize,
                            tilesCount: maxTiles
                        )
                    ),
                ]
            }
    }

    private static func previewName(
        _ base: String,
        widgetFamily: WidgetFamily,
        tilesCount: Int
    ) -> String {
        "\(base)-\(widgetFamily.description)-\(String(format: "%02d", tilesCount))_tiles"
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
            widgetKind: .custom,
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
    let showServerName: Bool
    let serverName: String?
    let widgetKind: WidgetsKind

    init(
        emptyViewGenerator: @escaping () -> AnyView,
        contents: [WidgetBasicViewModel],
        type: WidgetType,
        showLastUpdate: Bool = false,
        showServerName: Bool = false,
        serverName: String? = nil,
        widgetKind: WidgetsKind,
        family: WidgetFamily
    ) {
        self.emptyViewGenerator = emptyViewGenerator
        self.contents = contents
        self.type = type
        self.showLastUpdate = showLastUpdate
        self.family = family
        self.showServerName = showServerName
        self.serverName = serverName
        self.widgetKind = widgetKind
    }

    var body: some View {
        VStack {
            if contents.isEmpty {
                emptyViewGenerator()
            } else {
                content(for: Array(contents.prefix(WidgetFamilySizes.size(for: family))))
            }
            if showLastUpdate, !contents.isEmpty {
                lastUpdateFooter
            }
        }
        // Whenever Apple allow apps to use material backgrounds we should update this
        .widgetBackground(.primaryBackground)
    }

    /// The last refresh time doubles as the reload control, matching the energy widget: tapping the
    /// glyph or the time reloads this widget's timeline.
    @ViewBuilder
    private var lastUpdateFooter: some View {
        if #available(iOS 17, *) {
            HStack(spacing: DesignSystem.Spaces.half) {
                if showServerName, let serverName {
                    Text(verbatim: "\(serverName) ·")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                WidgetRefreshButton(kind: widgetKind, date: Current.date())
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, DesignSystem.Spaces.half)
            .padding(.bottom, DesignSystem.Spaces.half)
        }
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
        [.accessoryCircular, .accessoryRectangular]
    }
}
