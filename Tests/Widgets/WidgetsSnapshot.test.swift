@testable import HomeAssistant

import SharedTesting

import SnapshotTesting

import SwiftUI
import Testing
import WidgetKit

/* Some snapshots may look duplicate but they guarantee that if we pass more models to a widget container
 it will only displays what it's family supports guided by `WidgetFamilySizes` */
struct WidgetsSnapshotTests {
	@available(iOS 18, *)
	@MainActor @Test func systemLargeSnapshots() {
		WidgetBasicContainerView_Previews.systemLargeConfigurations.assertSnapshots(
			layout: .fixed(
				width: widthForPreview(family: .systemLarge),
				height: heightForPreview(family: .systemLarge)
			),
			traits: .init()
		)
	}
	
	@available(iOS 18, *)
	@MainActor @Test func systemMediumSnapshots() {
		WidgetBasicContainerView_Previews.systemMediumConfigurations.assertSnapshots(
			layout: .fixed(
				width: widthForPreview(family: .systemMedium),
				height: heightForPreview(family: .systemMedium)
			),
			traits: .init()
		)
	}
	
	@available(iOS 18, *)
	@MainActor @Test func systemSmallSnapshots() {
		WidgetBasicContainerView_Previews.systemSmallConfigurations.assertSnapshots(
			layout: .fixed(
				width: widthForPreview(family: .systemSmall),
				height: heightForPreview(family: .systemSmall)
			),
			traits: .init()
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

extension WidgetFamily: @retroactive EnvironmentKey {
    public static var defaultValue: WidgetFamily = .systemMedium
}

extension EnvironmentValues {
    var widgetFamily: WidgetFamily {
        get { self[WidgetFamily.self] }
        set { self[WidgetFamily.self] = newValue }
    }
}
