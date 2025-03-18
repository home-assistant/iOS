@testable import HomeAssistant

import SharedTesting

import Testing
import WidgetKit

struct WidgetsSnapshotTests {
    @available(iOS 18, *)
    @MainActor @Test func systemLargeSnapshots() {
        let size = snapshotSize(for: .systemLarge)
        WidgetBasicContainerView_Previews
            .systemLargeConfigurations
            .assertLightDarkSnapshots(
                layout: .fixed(
                    width: size.width,
                    height: size.height
                )
            )
    }

    @available(iOS 18, *)
    @MainActor @Test func systemMediumSnapshots() {
		let size = snapshotSize(for: .systemMedium)
        WidgetBasicContainerView_Previews
            .systemMediumConfigurations
            .assertLightDarkSnapshots(
                layout: .fixed(
                    width: size.width,
                    height: size.height
                )
            )
    }

    @available(iOS 18, *)
    @MainActor @Test func systemSmallSnapshots() {
		let size = snapshotSize(for: .systemSmall)
        WidgetBasicContainerView_Previews
            .systemSmallConfigurations
            .assertLightDarkSnapshots(
                layout: .fixed(
                    width: size.width,
                    height: size.height
                )
            )
    }

    private func snapshotSize(for family: WidgetFamily) -> CGSize {
        switch family {
        case .systemSmall:
            CGSize(width: 160, height: 160)
        case .systemMedium:
            CGSize(width: 350, height: 160)
        case .systemLarge:
            CGSize(width: 350, height: 310)
        default:
            CGSize(width: 600, height: 600)
        }
    }
}
