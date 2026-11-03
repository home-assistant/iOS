@testable import HomeAssistant

import Shared
import SharedTesting
import SwiftUI
import Testing
import WidgetKit

struct WidgetActionFeedbackSnapshotTests {
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
            of: WidgetTodoListView(
                serverId: "s",
                listId: "todo.shopping",
                title: "Shopping",
                items: [],
                isEmpty: false,
                loadFailed: true
            )
            .padding(),
            layout: .fixed(width: 338, height: 158)
        )
    }
}
