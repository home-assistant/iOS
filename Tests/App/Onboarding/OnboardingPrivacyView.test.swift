@testable import HomeAssistant
import Shared
import SnapshotTesting
import SwiftUI
import Testing

struct OnboardingPrivacyViewTests {
    @MainActor @Test func nothingSelectedSnapshot() async throws {
        guard #available(iOS 18.0, *) else { return }

        let view = OnboardingPrivacyView { _, _ in }

        assertLightDarkSnapshots(of: AnyView(view), named: "nothing-selected")
    }

    @MainActor @Test func nothingSharedSnapshot() async throws {
        guard #available(iOS 18.0, *) else { return }

        // `ServerSensorPrivacy.none` spelled out: against the optional parameter a bare `.none`
        // would be `Optional.none`, leaving the question unanswered.
        let view = OnboardingPrivacyView(locationPrivacy: .never, sensorPrivacy: ServerSensorPrivacy.none) { _, _ in }

        assertLightDarkSnapshots(of: AnyView(view), named: "nothing-shared")
    }

    @MainActor @Test func zoneOnlyLocationSnapshot() async throws {
        guard #available(iOS 18.0, *) else { return }

        let view = OnboardingPrivacyView(locationPrivacy: .zoneOnly, sensorPrivacy: .all) { _, _ in }

        assertLightDarkSnapshots(of: AnyView(view), named: "zone-only-location")
    }
}
