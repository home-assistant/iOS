import Foundation
import Shared
import SwiftUI

/// Holds the privacy choices `OnboardingPrivacyView` offers for a server being added to an app that
/// already has one onboarded.
///
/// Nothing is selected to begin with: the step exists because these choices were being applied
/// without anybody making them, so the flow waits for both of them rather than proposing any.
@MainActor
final class OnboardingPrivacyViewModel: ObservableObject {
    @Published var locationPrivacy: ServerLocationPrivacy?
    @Published var sensorPrivacy: ServerSensorPrivacy?

    private let action: (ServerLocationPrivacy, ServerSensorPrivacy) -> Void

    init(
        locationPrivacy: ServerLocationPrivacy? = nil,
        sensorPrivacy: ServerSensorPrivacy? = nil,
        action: @escaping (ServerLocationPrivacy, ServerSensorPrivacy) -> Void = { _, _ in }
    ) {
        self.locationPrivacy = locationPrivacy
        self.sensorPrivacy = sensorPrivacy
        self.action = action
    }

    /// Whether both questions have been answered; until they are, the step cannot be left.
    var canSubmit: Bool {
        locationPrivacy != nil && sensorPrivacy != nil
    }

    /// Hands the choices to whoever is running the onboarding flow.
    func submit() {
        guard let locationPrivacy, let sensorPrivacy else { return }
        action(locationPrivacy, sensorPrivacy)
    }

    var locationOptions: [SelectionOption] {
        [
            SelectionOption(
                value: ServerLocationPrivacy.exact.rawValue,
                title: ServerLocationPrivacy.exact.localizedDescription,
                subtitle: L10n.Onboarding.Privacy.Location.exactDescription,
                accessibilityIdentifier: AccessibilityIdentifier.onboardingPrivacyLocationExactOption.rawValue
            ),
            SelectionOption(
                value: ServerLocationPrivacy.zoneOnly.rawValue,
                title: ServerLocationPrivacy.zoneOnly.localizedDescription,
                subtitle: L10n.Onboarding.Privacy.Location.zoneOnlyDescription,
                accessibilityIdentifier: AccessibilityIdentifier.onboardingPrivacyLocationZoneOnlyOption.rawValue
            ),
            SelectionOption(
                value: ServerLocationPrivacy.never.rawValue,
                title: ServerLocationPrivacy.never.localizedDescription,
                subtitle: L10n.Onboarding.Privacy.Location.neverDescription,
                accessibilityIdentifier: AccessibilityIdentifier.onboardingPrivacyLocationNeverOption.rawValue
            ),
        ]
    }

    var sensorOptions: [SelectionOption] {
        [
            SelectionOption(
                value: ServerSensorPrivacy.all.rawValue,
                title: ServerSensorPrivacy.all.localizedDescription,
                subtitle: L10n.Onboarding.Privacy.Sensors.allDescription,
                accessibilityIdentifier: AccessibilityIdentifier.onboardingPrivacySensorsAllOption.rawValue
            ),
            SelectionOption(
                value: ServerSensorPrivacy.none.rawValue,
                title: ServerSensorPrivacy.none.localizedDescription,
                subtitle: L10n.Onboarding.Privacy.Sensors.noneDescription,
                accessibilityIdentifier: AccessibilityIdentifier.onboardingPrivacySensorsNoneOption.rawValue
            ),
        ]
    }

    /// `SelectionOptionView` selects by raw value; an unknown one leaves the current choice alone so
    /// a selection can never be lost.
    var locationSelection: Binding<String?> {
        Binding(get: {
            self.locationPrivacy?.rawValue
        }, set: { newValue in
            guard let newValue, let privacy = ServerLocationPrivacy(rawValue: newValue) else { return }
            self.locationPrivacy = privacy
        })
    }

    var sensorSelection: Binding<String?> {
        Binding(get: {
            self.sensorPrivacy?.rawValue
        }, set: { newValue in
            guard let newValue, let privacy = ServerSensorPrivacy(rawValue: newValue) else { return }
            self.sensorPrivacy = privacy
        })
    }
}
