import Foundation
import Shared

@MainActor
final class FocusSettingsViewModel: ObservableObject {
    @Published var focusNames: [FocusName] = []
    /// The name the Focus Filter last reported, shown so the user can tell the pairing worked.
    @Published var activeFocusName: String?
    @Published var isFocusSensorEnabled = false
    /// Without the Focus status permission nothing tells us a Focus ended, so the last name the
    /// filter reported would stay put.
    @Published var isFocusPermissionGranted = false

    func load() {
        focusNames = FocusName.all()
        activeFocusName = Current.focusFilter.activeFocusName()
        isFocusSensorEnabled = Current.sensors.isEnabled(uniqueID: WebhookSensorId.focusName.rawValue)
        isFocusPermissionGranted = Current.focusStatus.authorizationStatus() == .authorized
    }

    /// Whether the given text can be added, so the UI can keep the confirm button disabled instead
    /// of failing after the fact. Names are the sensor's state, so duplicates would be ambiguous.
    func canAdd(name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !focusNames.contains { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }
    }

    func add(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canAdd(name: trimmed) else { return }
        FocusName(name: trimmed).save()
        load()
    }

    func delete(_ focusName: FocusName) {
        focusName.delete()
        // A deleted name may still be selected in a Focus Filter, so stop reporting it right away.
        Current.focusFilter.forgetFocusName(focusName.name)
        load()
    }
}
