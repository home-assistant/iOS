@testable import HomeAssistant
import Shared
import Testing

@MainActor
struct DebugViewTests {
    /// Every row of the debugging screen is built inline in its body, so nothing else in the suite
    /// runs that code: a row that stopped resolving — a missing icon, a destination that no longer
    /// compiles into the list — would only show up when someone opened the screen by hand.
    /// Building the body is the assertion; it traps if a row cannot be constructed.
    @Test func theScreenBuildsItsRows() {
        _ = DebugView().body
    }

    @Test func theDeveloperSectionBuildsItsRows() {
        _ = DebugView().developerSection
    }

    @Test func theLocalPushStateToggleReadsAndWritesThePreference() {
        let original = Current.settingsStore.notifyOnLocalPushStateChanges
        defer { Current.settingsStore.notifyOnLocalPushStateChanges = original }

        let binding = DebugView.notifyOnLocalPushStateChangesBinding
        binding.wrappedValue = true
        #expect(Current.settingsStore.notifyOnLocalPushStateChanges)
        #expect(binding.wrappedValue)
        binding.wrappedValue = false
        #expect(!binding.wrappedValue)
    }

    @Test func theRegionEnterFuzzDistancePickerReadsAndWritesThePreference() {
        let original = Current.settingsStore.regionEnterMaximumFuzzDistance
        defer { Current.settingsStore.regionEnterMaximumFuzzDistance = original }

        let binding = DebugView.regionEnterMaximumFuzzDistanceBinding
        binding.wrappedValue = 500
        #expect(Current.settingsStore.regionEnterMaximumFuzzDistance == 500)
        #expect(binding.wrappedValue == 500)

        #expect(DebugView.regionEnterMaximumFuzzDistanceOptions.contains(
            SettingsStore.defaultRegionEnterMaximumFuzzDistance
        ))
        #expect(DebugView.regionEnterMaximumFuzzDistanceLabel(250) == "250m")
    }
}
