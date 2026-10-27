@testable import HomeAssistant
@testable import Shared
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

    @Test func simulatingARestoreMakesTheRestoredDevicePromptShow() {
        let prefs = Current.settingsStore.prefs
        let keys = [
            SettingsStore.integrationDeviceIDKey,
            SettingsStore.integrationDeviceIDOwnerKey,
            SettingsStore.registrationRecordsKey,
            RegistrationOwnership.earlierRegistrationsAdoptedKey,
        ]
        let previousValues = keys.map { prefs.object(forKey: $0) }
        let previousServers = Current.servers
        let previousVendorID = Current.device.identifierForVendor
        let previousIsCatalyst = Current.isCatalyst
        defer {
            Current.servers = previousServers
            Current.device.identifierForVendor = previousVendorID
            Current.isCatalyst = previousIsCatalyst
            for (key, value) in zip(keys, previousValues) {
                prefs.set(value, forKey: key)
            }
        }

        let servers = FakeServerManager(initial: 0)
        Current.servers = servers
        Current.device.identifierForVendor = { "this-device" }
        Current.isCatalyst = false
        keys.forEach(prefs.removeObject(forKey:))
        prefs.set("this-device", forKey: SettingsStore.integrationDeviceIDKey)
        let server = servers.addFake()
        #expect(!LaunchMessagesState.messagesToShow().map(\.id).contains("restoredRegistrations"))

        DebugView().simulateRestoredDevice()

        guard case let .restoredRegistrations(restored)? = LaunchMessagesState.messagesToShow().first else {
            Issue.record("Expected the restored device prompt to come first")
            return
        }
        #expect(restored == [server])
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
        _ = DebugView.regionEnterMaximumFuzzDistanceRow(250)
        _ = DebugView.regionEnterMaximumFuzzDistanceRows()
    }
}
