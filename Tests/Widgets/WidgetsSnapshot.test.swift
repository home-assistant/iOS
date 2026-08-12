@testable import HomeAssistant

import Shared
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
    @MainActor @Test func customWidgetStateColorSnapshot() {
        let size = snapshotSize(for: .systemSmall)
        let rules = [
            WidgetStateColorRule(
                comparison: .lessThan,
                threshold: 0,
                color: "#FF3B30",
                target: .state
            ),
        ]
        let item = MagicItem(
            id: "sensor.preview",
            serverId: WidgetPreviewSample.serverId,
            type: .entity,
            customization: .init(stateColorRules: rules),
            displayText: "Budget remaining"
        )
        let models = WidgetCustom().modelsForWidget(
            .init(id: "budget", name: "Budget", items: [item]),
            infoProvider: WidgetPreviewMagicItemProvider(),
            states: [
                item: .init(
                    value: "-18.39 $",
                    domainState: nil,
                    hexColor: nil,
                    numericValue: -18.39
                ),
            ],
            showStates: true
        )
        guard let model = models.first else {
            Issue.record("Expected the custom widget model to be created")
            return
        }

        assertLightDarkSnapshots(
            of: WidgetBasicContainerWrapperView(
                emptyViewGenerator: { AnyView(EmptyView()) },
                contents: [model],
                type: .custom,
                family: .systemSmall
            ),
            layout: .fixed(width: size.width, height: size.height),
            named: "customWidgetStateColor"
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
    @MainActor private func assertEnergySnapshot(
        source: WidgetEnergySource,
        withCost: Bool = true,
        family: WidgetFamily,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        let size = snapshotSize(for: family)
        let dayStart = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let points = (0 ..< 24).map { hour -> WidgetEnergyEntry.ChartPoint in
            let h = Double(hour)
            return WidgetEnergyEntry.ChartPoint(
                date: dayStart.addingTimeInterval(h * 3600),
                grid: 0.25 + 0.8 * exp(-pow(h - 7, 2) / 4) + 1.0 * exp(-pow(h - 20, 2) / 6),
                solar: h >= 6 && h <= 18 ? 1.6 * sin((h - 6) / 12 * .pi) : 0
            )
        }
        let entry = WidgetEnergyEntry(
            date: dayStart.addingTimeInterval(13 * 3600),
            period: .today,
            source: source,
            serverName: "Home",
            isConfigured: true,
            gridConsumed: 6.2,
            gridReturned: 10.5,
            solarGenerated: 12.4,
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
