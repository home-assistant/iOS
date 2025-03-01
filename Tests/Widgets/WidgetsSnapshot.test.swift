@testable import HomeAssistant
import SnapshotTesting
import SwiftUI
import Testing
import WidgetKit

/* Some snapshots may look duplicate but they guarantee that if we pass more models to a widget container
 it will only displays what it's family supports guided by `WidgetFamilySizes` */
struct WidgetsSnapshotTests {
    private let maxNumberOfTiles = 12

    @available(iOS 18, *)
    @MainActor @Test func snapshotSingleTileWithSubtitleAndWithIconBackgroundTest() {
        for familySize in WidgetCustomSupportedFamilies.families {
            for i in 0 ..< maxNumberOfTiles {
                let view = widgetBasicContainerView(
                    modelsCount: i + 1,
                    withSubtitle: true,
                    withIconBackgroundColor: true,
                    familySize: familySize
                )
                assertSnapshots(
                    of: view,
                    as: makeDefaultStrategies(
                        layout: .fixed(
                            width: widthForPreview(family: familySize),
                            height: heightForPreview(family: familySize)
                        )
                    ),
                    testName: testName(widgetFamily: familySize, tilesCount: i)
                )
            }
        }
    }

    @available(iOS 18, *)
    @MainActor @Test func snapshotSingleTileWithSubtitleAndWithoutIconBackgroundTest() {
        for familySize in WidgetCustomSupportedFamilies.families {
            for i in 0 ..< maxNumberOfTiles {
                let view = widgetBasicContainerView(
                    modelsCount: i + 1,
                    withSubtitle: true,
                    withIconBackgroundColor: false,
                    familySize: familySize
                )
                assertSnapshots(
                    of: view,
                    as: makeDefaultStrategies(
                        layout: .fixed(
                            width: widthForPreview(family: familySize),
                            height: heightForPreview(family: familySize)
                        )
                    ),
                    testName: testName(widgetFamily: familySize, tilesCount: i)
                )
            }
        }
    }

    @available(iOS 18, *)
    @MainActor @Test func snapshotSingleTileWithoutSubtitleAndWithIconBackgroundTest() {
        for familySize in WidgetCustomSupportedFamilies.families {
            for i in 0 ..< maxNumberOfTiles {
                let view = widgetBasicContainerView(
                    modelsCount: i + 1,
                    withSubtitle: false,
                    withIconBackgroundColor: true,
                    familySize: familySize
                )
                assertSnapshots(
                    of: view,
                    as: makeDefaultStrategies(
                        layout: .fixed(
                            width: widthForPreview(family: familySize),
                            height: heightForPreview(family: familySize)
                        )
                    ),
                    testName: testName(widgetFamily: familySize, tilesCount: i)
                )
            }
        }
    }

    @available(iOS 18, *)
    @MainActor @Test func snapshotSingleTileWithoutSubtitleAndWithoutIconBackgroundTest() {
        for familySize in WidgetCustomSupportedFamilies.families {
            for i in 0 ..< maxNumberOfTiles {
                let view = widgetBasicContainerView(
                    modelsCount: i + 1,
                    withSubtitle: false,
                    withIconBackgroundColor: false,
                    familySize: familySize
                )
                assertSnapshots(
                    of: view,
                    as: makeDefaultStrategies(
                        layout: .fixed(
                            width: widthForPreview(family: familySize),
                            height: heightForPreview(family: familySize)
                        )
                    ),
                    testName: testName(widgetFamily: familySize, tilesCount: i)
                )
            }
        }
    }

    private func testName(
        base: String = #function,
        widgetFamily: WidgetFamily,
        tilesCount: Int
    ) -> String {
        "\(base).\(widgetFamily.description).\(tilesCount)_tiles"
    }

    private func heightForPreview(family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemSmall, .systemMedium:
            return 160
        case .systemLarge:
            return 310
        default:
            return 600
        }
    }

    private func widthForPreview(family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemSmall:
            return 160
        case .systemMedium, .systemLarge:
            return 350
        default:
            return 600
        }
    }

    private func widgetBasicContainerView(
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

    private func models(count: Int, withSubtitle: Bool, withIconBackgroundColor: Bool) -> [WidgetBasicViewModel] {
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

extension WidgetFamily: @retroactive EnvironmentKey {
    public static var defaultValue: WidgetFamily = .systemMedium
}

extension EnvironmentValues {
    var widgetFamily: WidgetFamily {
        get { self[WidgetFamily.self] }
        set { self[WidgetFamily.self] = newValue }
    }
}
