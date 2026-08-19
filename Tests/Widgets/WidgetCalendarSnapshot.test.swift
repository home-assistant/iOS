@testable import HomeAssistant

import Foundation
import Shared
import SharedTesting

import SwiftUI
import Testing
import WidgetKit

/// Renders the calendar widget at every family it supports, in light and dark.
///
/// The view takes both its "now" and its `Calendar` as parameters, so these fix a UTC, en_US_POSIX
/// calendar and a fixed reference date rather than overriding `Current` — the snapshots then come
/// out identical whatever region and time zone the machine running them is set to.
struct WidgetCalendarSnapshotTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    private static var referenceDate: Date { WidgetCalendarPreviewSample.referenceDate }

    private static func events(_ count: Int) -> [WidgetCalendarEvent] {
        WidgetCalendarEvent.upcoming(
            WidgetCalendarPreviewSample.events(referenceDate: referenceDate, calendar: calendar),
            at: referenceDate,
            limit: count,
            calendar: calendar
        )
    }

    @available(iOS 18, *)
    @MainActor @Test func systemSmallSnapshot() {
        assertCalendarSnapshot(
            family: .systemSmall,
            events: Self.events(WidgetFamilySizes.calendarSize(for: .systemSmall)),
            showsCalendarName: false
        )
    }

    @available(iOS 18, *)
    @MainActor @Test func systemMediumSnapshot() {
        assertCalendarSnapshot(
            family: .systemMedium,
            events: Self.events(WidgetFamilySizes.calendarSize(for: .systemMedium)),
            showsCalendarName: true
        )
    }

    @available(iOS 18, *)
    @MainActor @Test func systemLargeSnapshot() {
        assertCalendarSnapshot(
            family: .systemLarge,
            events: Self.events(WidgetFamilySizes.calendarSize(for: .systemLarge)),
            showsCalendarName: true
        )
    }

    /// The list spilling into the following day, which is the case the day label exists for: the
    /// families without a day heading carry no other date, so an unlabelled row for tomorrow reads
    /// as belonging to the badge.
    @available(iOS 18, *)
    @MainActor @Test func systemMediumNextDaySnapshot() {
        let spanning = Self.events(10)
            .dropFirst(2)
            .prefix(WidgetFamilySizes.calendarSize(for: .systemMedium))
        assertCalendarSnapshot(
            family: .systemMedium,
            events: Array(spanning),
            showsCalendarName: true
        )
    }

    /// A configured widget on a quiet fortnight still shows the date, which is what separates this
    /// from the unconfigured state below.
    @available(iOS 18, *)
    @MainActor @Test func systemMediumNoEventsSnapshot() {
        assertCalendarSnapshot(family: .systemMedium, events: [], showsCalendarName: false)
    }

    /// What a freshly dropped widget shows when the app has no calendars stored yet.
    @available(iOS 18, *)
    @MainActor @Test func systemMediumNotConfiguredSnapshot() {
        assertCalendarSnapshot(
            family: .systemMedium,
            events: [],
            calendarCount: 0,
            showsCalendarName: false
        )
    }

    @available(iOS 18, *)
    @MainActor private func assertCalendarSnapshot(
        family: WidgetFamily,
        events: [WidgetCalendarEvent],
        calendarCount: Int = 3,
        showsCalendarName: Bool,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        let size = snapshotSize(for: family)
        assertLightDarkSnapshots(
            of: WidgetCalendarView(
                referenceDate: Self.referenceDate,
                events: events,
                calendarCount: calendarCount,
                showsCalendarName: showsCalendarName,
                calendar: Self.calendar,
                serverId: calendarCount == 0 ? nil : "server"
            )
            .padding(DesignSystem.Spaces.two)
            .background(Color(uiColor: .systemBackground))
            .environment(\.widgetFamily, family),
            layout: .fixed(width: size.width, height: size.height),
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }

    /// The home screen widget sizes on a current iPhone, so a layout that only just fits here only
    /// just fits on device too.
    private func snapshotSize(for family: WidgetFamily) -> CGSize {
        switch family {
        case .systemSmall:
            CGSize(width: 170, height: 170)
        case .systemMedium:
            CGSize(width: 364, height: 170)
        default:
            CGSize(width: 364, height: 382)
        }
    }
}
