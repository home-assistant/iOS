@testable import HomeAssistant

import HAWatchComplications
import Shared
import SharedTesting
import SwiftUI
import Testing
import WidgetKit

struct WidgetActionFeedbackSnapshotTests {
    @available(iOS 17, *)
    @MainActor @Test func gaugeContentSupportsPendingFeedback() {
        assertLightDarkSnapshots(
            of: HStack {
                WidgetGaugeView(entry: .init(
                    gaugeType: .normal,
                    value: 0.67,
                    valueLabel: "67%",
                    runScript: false,
                    script: nil,
                    showConfirmationNotification: false
                ))
                WidgetGaugeView(entry: .init(
                    gaugeType: .normal,
                    value: 0.67,
                    valueLabel: "67%",
                    complicationModel: .init(
                        valueText: "67%",
                        showsValue: true,
                        title: "Battery",
                        showsName: true,
                        fraction: 0.67,
                        minLabel: "0",
                        maxLabel: "100",
                        tint: .green
                    ),
                    runScript: false,
                    script: nil,
                    showConfirmationNotification: false
                ))
            }
            .padding(),
            layout: .fixed(width: 360, height: 180)
        )
    }

    @available(iOS 17, *)
    @MainActor @Test func optimisticSplitEntityStates() {
        assertLightDarkSnapshots(
            of: HStack {
                ForEach([false, true], id: \.self) { isOn in
                    WidgetTileView(
                        model: .init(id: "light", title: "Kitchen light", icon: .lightbulbIcon),
                        sizeStyle: .single,
                        family: .systemSmall,
                        kind: .button,
                        regions: .init(
                            icon: { label in
                                AnyView(
                                    Toggle(isOn: .constant(isOn)) { label }
                                        .toggleStyle(WidgetEntityToggleStyle(
                                            initialIsOn: false,
                                            onColor: .orange,
                                            offColor: .gray
                                        ))
                                )
                            },
                            body: { $0 }
                        )
                    )
                }
            }
            .padding(),
            layout: .fixed(width: 360, height: 180)
        )
    }

    @available(iOS 17, *)
    @MainActor @Test func optimisticEntityStates() {
        assertLightDarkSnapshots(
            of: HStack {
                ForEach([false, true], id: \.self) { isOn in
                    Toggle(isOn: .constant(isOn)) {
                        WidgetTileView(
                            model: .init(id: "light", title: "Kitchen light", icon: .lightbulbIcon),
                            sizeStyle: .single,
                            family: .systemSmall,
                            kind: .button
                        )
                    }
                    .toggleStyle(WidgetEntityToggleStyle(initialIsOn: false, onColor: .orange, offColor: .gray))
                }
            }
            .padding(),
            layout: .fixed(width: 360, height: 180)
        )
    }

    @available(iOS 17, *)
    @MainActor @Test func optimisticTodoStates() {
        assertLightDarkSnapshots(
            of: HStack {
                ForEach([false, true], id: \.self) { isCompleted in
                    Toggle(isOn: .constant(isCompleted)) {
                        WidgetTodoCheckboxView()
                            .font(.title)
                            .foregroundStyle(.haPrimary)
                    }
                    .toggleStyle(WidgetTodoToggleStyle())
                }
            }
            .padding(),
            layout: .fixed(width: 160, height: 70)
        )
    }

    @available(iOS 17, *)
    @MainActor @Test func failedTodoRefreshDoesNotClaimCompletion() {
        assertLightDarkSnapshots(
            of: WidgetTodoListView(entry: .init(
                date: Date(timeIntervalSince1970: 0),
                serverId: "s",
                listId: "todo.shopping",
                listTitle: "Shopping",
                items: [],
                family: .systemMedium,
                loadFailed: true
            ))
            .padding(),
            layout: .fixed(width: 338, height: 158)
        )
    }
}
