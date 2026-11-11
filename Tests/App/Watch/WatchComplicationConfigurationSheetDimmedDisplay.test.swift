@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// The "Show when inactive" choice in the complication's Customize sheet: what the toggle reads for a
/// config saved before it existed, that flipping it is what the watch later reads, and how the section
/// looks. The watch-side hiding lives in the widget extension, which no unit-test target builds.
@MainActor
struct WatchComplicationConfigurationSheetDimmedDisplayTests {
    @Test func showWhenInactiveReadsOnUntilTurnedOff() {
        let viewModel = WatchComplicationBuilderEditViewModel(
            existing: WatchComplicationConfig(serverId: "server-1", entityId: "sensor.net_worth")
        )
        let sheet = WatchComplicationConfigurationSheet(viewModel: viewModel)

        // Saved before the toggle existed: nothing stored, which must still mean "shown".
        #expect(viewModel.config.showWhenInactive == nil)
        #expect(sheet.showWhenInactiveBinding.wrappedValue)

        sheet.showWhenInactiveBinding.wrappedValue = false
        #expect(viewModel.config.showWhenInactive == false)
        #expect(viewModel.config.showsWhenInactive() == false)
        #expect(!sheet.showWhenInactiveBinding.wrappedValue)

        sheet.showWhenInactiveBinding.wrappedValue = true
        #expect(viewModel.config.showsWhenInactive())
    }

    @Test func dimmedDisplaySection() {
        let viewModel = WatchComplicationBuilderEditViewModel(
            existing: WatchComplicationConfig(serverId: "server-1", entityId: "sensor.net_worth")
        )
        assertLightDarkSnapshots(
            of: Form { WatchComplicationConfigurationSheet(viewModel: viewModel).dimmedDisplaySection }
        )
    }
}
