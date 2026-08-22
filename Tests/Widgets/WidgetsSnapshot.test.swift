@testable import HomeAssistant

import SharedTesting

import SwiftUI
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

    @available(iOS 18, *)
    @MainActor @Test func gaugeWidgetSystemSmallSnapshot() {
        assertGaugeSnapshot(
            gaugeType: .normal,
            min: "0",
            max: "100",
            family: .systemSmall
        )
    }

    @available(iOS 18, *)
    @MainActor @Test func gaugeWidgetSystemSmallSingleLabelSnapshot() {
        assertGaugeSnapshot(
            gaugeType: .singleLabel,
            label: "Battery",
            family: .systemSmall
        )
    }

    @available(iOS 18, *)
    @MainActor @Test func gaugeWidgetSystemSmallCapacitySnapshot() {
        assertGaugeSnapshot(
            gaugeType: .capacity,
            family: .systemSmall
        )
    }

    @available(iOS 18, *)
    @MainActor private func assertGaugeSnapshot(
        gaugeType: GaugeTypeAppEnum,
        label: String? = nil,
        min: String? = nil,
        max: String? = nil,
        family: WidgetFamily,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        let size = snapshotSize(for: family)
        let entry = WidgetGaugeEntry(
            gaugeType: gaugeType,
            value: 0.84,
            valueLabel: "84%",
            label: label,
            min: min,
            max: max,
            runScript: false,
            script: nil,
            showConfirmationNotification: true
        )
        assertLightDarkSnapshots(
            of: WidgetGaugeView(entry: entry)
                .environment(\.widgetFamily, family),
            layout: .fixed(width: size.width, height: size.height),
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }

    @available(iOS 18, *)
    @MainActor @Test func energyWidgetSystemSmallSnapshot() {
        assertEnergySnapshot(source: .auto, family: .systemSmall)
    }

    @available(iOS 18, *)
    @MainActor @Test func energyWidgetSystemMediumSnapshot() {
        assertEnergySnapshot(source: .auto, family: .systemMedium)
    }

    @available(iOS 18, *)
    @MainActor @Test func energyWidgetSystemMediumSolarOnlySnapshot() {
        assertEnergySnapshot(source: .solar, withCost: false, family: .systemMedium)
    }

    @available(iOS 18, *)
    @MainActor @Test func energyWidgetSystemMediumConsumptionOnlySnapshot() {
        assertEnergySnapshot(source: .consumption, family: .systemMedium)
    }

    @available(iOS 18, *)
    @MainActor @Test func energyWidgetSystemLargeSnapshot() {
        assertEnergySnapshot(source: .auto, family: .systemLarge)
    }

    /// A home exporting most of what it generates: the chart has to give the purple returned-energy
    /// bars room below the axis instead of letting the orange stack swallow them.
    @available(iOS 18, *)
    @MainActor @Test func energyWidgetHeavyExportSystemMediumSnapshot() {
        assertEnergySnapshot(source: .auto, scenario: .heavyExport, family: .systemMedium)
    }

    @available(iOS 18, *)
    @MainActor @Test func energyWidgetHeavyExportSystemLargeSnapshot() {
        assertEnergySnapshot(source: .auto, scenario: .heavyExport, family: .systemLarge)
    }

    /// Exported energy belongs to the grid series, so hiding the grid hides it too — and with no
    /// export drawn, the solar bars go back to showing the full generation.
    @available(iOS 18, *)
    @MainActor @Test func energyWidgetHeavyExportSolarOnlySnapshot() {
        assertEnergySnapshot(source: .solar, withCost: false, scenario: .heavyExport, family: .systemMedium)
    }

    @available(iOS 18, *)
    @MainActor @Test func energyWidgetHeavyExportConsumptionOnlySnapshot() {
        assertEnergySnapshot(source: .consumption, scenario: .heavyExport, family: .systemMedium)
    }

    /// No solar panels: grid consumption only, and nothing below the axis at all.
    @available(iOS 18, *)
    @MainActor @Test func energyWidgetNoSolarSystemMediumSnapshot() {
        assertEnergySnapshot(source: .auto, scenario: .noSolar, family: .systemMedium)
    }

    /// Solar with no export meter configured: generation stacks in full, because there is no
    /// exported share to take off it.
    @available(iOS 18, *)
    @MainActor @Test func energyWidgetSolarWithoutExportSystemMediumSnapshot() {
        assertEnergySnapshot(source: .auto, scenario: .solarWithoutExport, family: .systemMedium)
    }

    /// Daily buckets rather than hourly, with the whole week on the x-axis.
    @available(iOS 18, *)
    @MainActor @Test func energyWidgetThisWeekSystemMediumSnapshot() {
        assertEnergySnapshot(source: .auto, period: .thisWeek, family: .systemMedium)
    }

    /// A month's worth of daily buckets, labelled every seventh day.
    @available(iOS 18, *)
    @MainActor @Test func energyWidgetThisMonthSystemMediumSnapshot() {
        assertEnergySnapshot(source: .auto, period: .thisMonth, family: .systemMedium)
    }

    @available(iOS 18, *)
    @MainActor @Test func energyWidgetYesterdaySystemMediumSnapshot() {
        assertEnergySnapshot(source: .auto, period: .yesterday, family: .systemMedium)
    }

    @available(iOS 18, *)
    @MainActor @Test func energyWidgetNoDataSystemSmallSnapshot() {
        assertEnergyNoDataSnapshot(family: .systemSmall)
    }

    @available(iOS 18, *)
    @MainActor @Test func energyWidgetNoDataSystemMediumSnapshot() {
        assertEnergyNoDataSnapshot(family: .systemMedium)
    }

    @available(iOS 18, *)
    @MainActor @Test func energyWidgetNotConfiguredSnapshot() {
        let size = snapshotSize(for: .systemMedium)
        assertLightDarkSnapshots(
            of: WidgetEnergyView(entry: WidgetEnergyEntry(period: .today, isConfigured: false))
                .environment(\.widgetFamily, .systemMedium),
            layout: .fixed(width: size.width, height: size.height)
        )
    }

    @available(iOS 18, *)
    @MainActor @Test func energyWidgetNoConnectionSystemSmallSnapshot() {
        assertEnergyNoConnectionSnapshot(family: .systemSmall)
    }

    @available(iOS 18, *)
    @MainActor @Test func energyWidgetNoConnectionSystemMediumSnapshot() {
        assertEnergyNoConnectionSnapshot(family: .systemMedium)
    }

    @available(iOS 18, *)
    @MainActor @Test func energyWidgetNoConnectionAccessoryRectangularSnapshot() {
        let size = snapshotSize(for: .accessoryRectangular)
        assertLightDarkSnapshots(
            of: WidgetEnergyAccessoryRectangularView(entry: Self.noConnectionEntry)
                .environment(\.widgetFamily, .accessoryRectangular),
            layout: .fixed(width: size.width, height: size.height)
        )
    }

    @available(iOS 18, *)
    @MainActor @Test func energyWidgetNoConnectionAccessoryInlineSnapshot() {
        let size = snapshotSize(for: .accessoryInline)
        assertLightDarkSnapshots(
            of: WidgetEnergyAccessoryInlineView(entry: Self.noConnectionEntry)
                .environment(\.widgetFamily, .accessoryInline),
            layout: .fixed(width: size.width, height: size.height)
        )
    }

    @available(iOS 17, *)
    private static var noConnectionEntry: WidgetEnergyEntry {
        WidgetEnergyEntry(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            period: .today,
            source: .auto,
            serverName: "Home",
            isConfigured: false,
            noConnection: true
        )
    }

    @available(iOS 18, *)
    @MainActor private func assertEnergyNoConnectionSnapshot(
        family: WidgetFamily,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        let size = snapshotSize(for: family)
        assertLightDarkSnapshots(
            of: WidgetEnergyView(entry: Self.noConnectionEntry)
                .environment(\.widgetFamily, family)
                .environment(\.locale, Locale(identifier: "en_US")),
            layout: .fixed(width: size.width, height: size.height),
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }

    /// Configured, but the server has nothing for the period yet — early in the day, typically. The
    /// figures blank out and the chart draws empty instead of the card becoming a "no data" line.
    @available(iOS 18, *)
    @MainActor private func assertEnergyNoDataSnapshot(
        family: WidgetFamily,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        let size = snapshotSize(for: family)
        let dayStart = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let entry = WidgetEnergyEntry(
            date: dayStart.addingTimeInterval(2 * 3600),
            period: .today,
            source: .auto,
            serverName: "Home",
            isConfigured: true
        )
        assertLightDarkSnapshots(
            of: WidgetEnergyView(entry: entry)
                .environment(\.widgetFamily, family)
                .environment(\.locale, Locale(identifier: "en_US")),
            layout: .fixed(width: size.width, height: size.height),
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }

    @available(iOS 18, *)
    @MainActor private func assertEnergySnapshot(
        source: WidgetEnergySource,
        withCost: Bool = true,
        scenario: EnergyScenario = .solarDay,
        period: WidgetEnergyPeriod = .today,
        family: WidgetFamily,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        let size = snapshotSize(for: family)
        let points = scenario.points(period: period)
        let totals = WidgetEnergyChartSample.totals(of: points)
        let entry = WidgetEnergyEntry(
            date: Self.dayStart.addingTimeInterval(13 * 3600),
            period: period,
            source: source,
            serverName: "Home",
            isConfigured: true,
            gridConsumed: totals.gridConsumed,
            gridReturned: totals.gridReturned,
            solarGenerated: scenario == .noSolar ? nil : totals.solarGenerated,
            cost: withCost ? -0.49 : nil,
            currencyCode: withCost ? "EUR" : nil,
            chartPoints: points
        )
        assertLightDarkSnapshots(
            // Pinned so the refresh time doesn't render 12- or 24-hour depending on the machine.
            of: WidgetEnergyView(entry: entry)
                .environment(\.widgetFamily, family)
                .environment(\.locale, Locale(identifier: "en_US")),
            layout: .fixed(width: size.width, height: size.height),
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }

    private static let dayStart = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))

    /// The homes the energy chart has to draw. Each one exercises a different shape of the stack:
    /// which series exist, whether anything is exported, and how the bars sit against the axis.
    @available(iOS 17, *)
    private enum EnergyScenario {
        /// Solar covering part of the day and exporting its midday surplus — the common case, and
        /// the one where the exported share has to come off the orange bar.
        case solarDay
        /// A clear summer day generating far more than the home uses: most of the chart hangs below
        /// the axis, so the negative half has to be scaled for rather than clipped.
        case heavyExport
        /// No solar at all: grid consumption only, and never a bar below the axis.
        case noSolar
        /// Solar with no export meter configured — generation is all the widget knows about.
        case solarWithoutExport

        func points(period: WidgetEnergyPeriod) -> [WidgetEnergyEntry.ChartPoint] {
            let isDaily = period == .thisWeek || period == .thisMonth
            return Self.buckets(for: period, daily: isDaily).enumerated().map { index, date in
                // An hourly bucket is one point on the day's curve; a daily bucket is the whole
                // day, so it sums the same curve. Sunnier and cloudier days alternate, otherwise a
                // week renders as a row of identical bars.
                let hours = isDaily ? (0 ..< 24).map(Double.init) : [Double(index)]
                let sunniness = isDaily ? 0.5 + 0.25 * Double(index % 4) : 1
                var grid = 0.0
                var solar = 0.0
                var returned = 0.0
                for hour in hours {
                    let hourly = flows(atHour: hour, sunniness: sunniness)
                    grid += hourly.grid
                    solar += hourly.solar
                    returned += hourly.returned
                }
                return WidgetEnergyEntry.ChartPoint(date: date, grid: grid, solar: solar, gridReturned: returned)
            }
        }

        /// One hour's grid draw, generation and export, derived from each other the way a real
        /// home's are: the house imports whatever solar can't cover, and exports the surplus.
        private func flows(atHour hour: Double, sunniness: Double)
            -> (grid: Double, solar: Double, returned: Double) {
            // Household demand peaks in the morning and again in the evening; solar peaks midday.
            let load = 0.25 + 0.8 * exp(-pow(hour - 7, 2) / 4) + 1.0 * exp(-pow(hour - 20, 2) / 6)
            let daylight = hour >= 6 && hour <= 18 ? 1.6 * sin((hour - 6) / 12 * .pi) : 0
            let solar: Double = switch self {
            case .noSolar: 0
            case .heavyExport: daylight * sunniness * 4
            case .solarDay, .solarWithoutExport: daylight * sunniness
            }
            return (
                grid: max(load - solar, 0),
                solar: solar,
                returned: self == .solarWithoutExport ? 0 : max(solar - load, 0)
            )
        }

        private static func buckets(for period: WidgetEnergyPeriod, daily: Bool) -> [Date] {
            let start = WidgetsSnapshotTests.dayStart
            guard daily else {
                return (0 ..< 24).map { start.addingTimeInterval(Double($0) * 3600) }
            }
            return (0 ..< (period == .thisMonth ? 28 : 7)).map { start.addingTimeInterval(Double($0) * 24 * 3600) }
        }
    }

    private func snapshotSize(for family: WidgetFamily) -> CGSize {
        switch family {
        case .systemSmall:
            CGSize(width: 160, height: 160)
        case .systemMedium:
            CGSize(width: 350, height: 160)
        case .systemLarge:
            CGSize(width: 350, height: 310)
        case .accessoryRectangular:
            CGSize(width: 172, height: 76)
        case .accessoryInline:
            CGSize(width: 250, height: 24)
        default:
            CGSize(width: 600, height: 600)
        }
    }
}
