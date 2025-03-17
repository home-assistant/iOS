@testable import HomeAssistant

import SharedTesting

import Testing
import WidgetKit

struct WidgetsSnapshotTests {
    @available(iOS 18, *)
    @MainActor @Test func systemLargeSnapshots() {
        WidgetBasicContainerView_Previews.systemLargeConfigurations.assertLightDarkSnapshots(
            layout: .fixed(
                width: widthForPreview(family: .systemLarge),
                height: heightForPreview(family: .systemLarge)
            )
        )
    }

    @available(iOS 18, *)
    @MainActor @Test func systemMediumSnapshots() {
        WidgetBasicContainerView_Previews.systemMediumConfigurations.assertLightDarkSnapshots(
            layout: .fixed(
                width: widthForPreview(family: .systemMedium),
                height: heightForPreview(family: .systemMedium)
            )
        )
    }

    @available(iOS 18, *)
    @MainActor @Test func systemSmallSnapshots() {
        WidgetBasicContainerView_Previews.systemSmallConfigurations.assertLightDarkSnapshots(
            layout: .fixed(
                width: widthForPreview(family: .systemSmall),
                height: heightForPreview(family: .systemSmall)
            )
        )
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
}
