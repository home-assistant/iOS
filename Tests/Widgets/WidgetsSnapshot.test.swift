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
    @MainActor @Test func gaugeWidgetAccessoryCircularSnapshot() {
        assertGaugeSnapshot(
            gaugeType: .normal,
            min: "0",
            max: "100",
            family: .accessoryCircular
        )
    }

    @available(iOS 18, *)
    @MainActor @Test func gaugeWidgetAccessoryCircularSingleLabelSnapshot() {
        assertGaugeSnapshot(
            gaugeType: .singleLabel,
            label: "Battery",
            family: .accessoryCircular
        )
    }

    @available(iOS 18, *)
    @MainActor @Test func gaugeWidgetAccessoryCircularCapacitySnapshot() {
        assertGaugeSnapshot(
            gaugeType: .capacity,
            family: .accessoryCircular
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

    private func snapshotSize(for family: WidgetFamily) -> CGSize {
        switch family {
        case .systemSmall:
            CGSize(width: 160, height: 160)
        case .systemMedium:
            CGSize(width: 350, height: 160)
        case .systemLarge:
            CGSize(width: 350, height: 310)
        case .accessoryCircular:
            CGSize(width: 72, height: 72)
        default:
            CGSize(width: 600, height: 600)
        }
    }
}
