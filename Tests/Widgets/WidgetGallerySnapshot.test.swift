@testable import HomeAssistant

import Shared
import SharedTesting

import SwiftUI
import Testing
import WidgetKit

/// Renders every entry of the design system's widget gallery, at each family it supports, in light
/// and dark.
///
/// The gallery draws the same components the widgets do, from mocked data, so this covers the whole
/// widget layer in one place — and the recorded images double as the reference for what the gallery
/// actually shows.
struct WidgetGallerySnapshotTests {
    /// Room for the family caption above the widget and the padding around it.
    private static let captionHeight: CGFloat = 28
    private static let padding: CGFloat = 16

    @available(iOS 18, *)
    @MainActor @Test(arguments: WidgetGalleryItem.allCases)
    func gallerySnapshot(item: WidgetGalleryItem) {
        for family in item.families {
            let size = WidgetGalleryFamilyMetrics.size(for: family)
            assertLightDarkSnapshots(
                of: WidgetGalleryPreview(family: family) {
                    item.preview(for: family)
                }
                .padding(Self.padding),
                layout: .fixed(
                    width: size.width + Self.padding * 2,
                    height: size.height + Self.captionHeight + Self.padding * 2
                ),
                named: "\(item.rawValue)-\(Self.name(for: family))"
            )
        }
    }

    private static func name(for family: WidgetFamily) -> String {
        switch family {
        case .systemSmall: "systemSmall"
        case .systemMedium: "systemMedium"
        case .systemLarge: "systemLarge"
        case .accessoryCircular: "accessoryCircular"
        case .accessoryRectangular: "accessoryRectangular"
        case .accessoryInline: "accessoryInline"
        default: "other"
        }
    }
}
