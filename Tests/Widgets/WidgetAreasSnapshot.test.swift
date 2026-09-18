@testable import HomeAssistant

import Shared
import SharedTesting

import SwiftUI
import Testing
import WidgetKit

/// Renders the areas widget at every family it supports, in light and dark.
///
/// The entries are built from the design system's sample home rather than from a database, so the
/// snapshots show the same floors and areas on every machine — and every page but the last one is
/// full, which is what puts the paging arrows in the corners.
struct WidgetAreasSnapshotTests {
    private static func entry(
        family: WidgetFamily,
        page: Int = 0,
        sections: [WidgetAreaFloorSection] = WidgetAreasSampleData.sections
    ) -> WidgetAreasEntry {
        let pages = WidgetAreasLayout.pages(sections: sections, family: family)
        return .init(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            page: pages.indices.contains(page) ? pages[page] : .init(id: 0, sections: []),
            pageCount: pages.count,
            serverId: "server",
            serverName: "Home",
            dashboardPath: "home"
        )
    }

    @available(iOS 18, *)
    @MainActor @Test func systemSmallSnapshot() {
        assertAreasSnapshot(family: .systemSmall, entry: Self.entry(family: .systemSmall))
    }

    @available(iOS 18, *)
    @MainActor @Test func systemMediumSnapshot() {
        assertAreasSnapshot(family: .systemMedium, entry: Self.entry(family: .systemMedium))
    }

    @available(iOS 18, *)
    @MainActor @Test func systemLargeSnapshot() {
        assertAreasSnapshot(family: .systemLarge, entry: Self.entry(family: .systemLarge))
    }

    @available(iOS 18, *)
    @MainActor @Test func systemExtraLargeSnapshot() {
        assertAreasSnapshot(family: .systemExtraLarge, entry: Self.entry(family: .systemExtraLarge))
    }

    /// The portrait extra-large family iOS 27 added: a large widget's two columns, and the height of
    /// two of them stacked, so the whole home fits on one page and the arrows stay away.
    @available(iOS 27, *)
    @MainActor @Test func systemExtraLargePortraitSnapshot() {
        assertAreasSnapshot(family: .systemExtraLargePortrait, entry: Self.entry(family: .systemExtraLargePortrait))
    }

    /// A page in the middle of the home: both arrows live, and the floor that ran over carries its
    /// heading with it.
    @available(iOS 18, *)
    @MainActor @Test func systemMediumSecondPageSnapshot() {
        assertAreasSnapshot(family: .systemMedium, entry: Self.entry(family: .systemMedium, page: 1))
    }

    /// The last page: the forward arrow stays in place, faded, so the footer doesn't shift as you
    /// page through the home.
    @available(iOS 18, *)
    @MainActor @Test func systemLargeLastPageSnapshot() {
        assertAreasSnapshot(family: .systemLarge, entry: Self.entry(family: .systemLarge, page: 1))
    }

    /// A server whose areas have no floors: no headings, and one page holds more of them.
    @available(iOS 18, *)
    @MainActor @Test func systemMediumWithoutFloorsSnapshot() {
        assertAreasSnapshot(
            family: .systemMedium,
            entry: Self.entry(family: .systemMedium, sections: WidgetAreasSampleData.sectionsWithoutFloors)
        )
    }

    /// A home with few enough areas to fit at once shows no arrows at all — only the server.
    @available(iOS 18, *)
    @MainActor @Test func systemMediumSinglePageSnapshot() {
        assertAreasSnapshot(
            family: .systemMedium,
            entry: Self.entry(
                family: .systemMedium,
                sections: Array(WidgetAreasSampleData.sections.prefix(1)).map {
                    WidgetAreaFloorSection(id: $0.id, title: $0.title, icon: $0.icon, areas: Array($0.areas.prefix(2)))
                }
            )
        )
    }

    /// The entry the widget gallery draws: the sample home, and no server to open an area on, so
    /// the tiles carry no links.
    @available(iOS 18, *)
    @MainActor @Test func systemMediumPreviewEntrySnapshot() {
        assertAreasSnapshot(family: .systemMedium, entry: .preview(family: .systemMedium))
    }

    /// What a freshly dropped widget shows on a server with no areas stored yet.
    @available(iOS 18, *)
    @MainActor @Test func systemMediumEmptySnapshot() {
        assertAreasSnapshot(family: .systemMedium, entry: Self.entry(family: .systemMedium, sections: []))
    }

    @available(iOS 18, *)
    @MainActor private func assertAreasSnapshot(
        family: WidgetFamily,
        entry: WidgetAreasEntry,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        MaterialDesignIcons.register()
        let size = snapshotSize(for: family)
        assertLightDarkSnapshots(
            of: WidgetAreasView(entry: entry)
                .environment(\.widgetFamily, family),
            layout: .fixed(width: size.width, height: size.height),
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }

    /// The home screen widget sizes on a current iPhone, and the iPad for the extra large families,
    /// so a layout that only just fits here only just fits on device too. The portrait one is two
    /// large widgets stacked, with the gap the home screen leaves between them.
    private func snapshotSize(for family: WidgetFamily) -> CGSize {
        switch family {
        case .systemSmall:
            CGSize(width: 170, height: 170)
        case .systemMedium:
            CGSize(width: 364, height: 170)
        case .systemExtraLarge:
            CGSize(width: 715, height: 382)
        case .systemExtraLargePortrait:
            // Measured off the family as an iPhone actually draws it. It was guessed at 364x806,
            // half a large widget taller than the real thing, which is what let the tiles be sized
            // for rows they never got.
            CGSize(width: 350, height: 564)
        default:
            CGSize(width: 364, height: 382)
        }
    }
}
