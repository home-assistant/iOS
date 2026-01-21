import Foundation
import Shared

final class GesturesSetupViewModel: ObservableObject {
    @Published var settings: [AppGesture: HAGestureAction] = [:]
    @Published var assistConfiguration: GestureAssistConfiguration = .default

    init() {
        self.settings = Current.settingsStore.gestures
        self.assistConfiguration = Current.settingsStore.gestureAssistConfiguration
    }

    func selection(for gesture: AppGesture) -> HAGestureAction {
        settings[gesture] ?? .none
    }

    func setSelection(for gesture: AppGesture, newValue: HAGestureAction) {
        Current.settingsStore.gestures[gesture] = newValue
        sync()
    }

    func resetGestures() {
        Current.settingsStore.gestures = .defaultGestures
        Current.settingsStore.gestureAssistConfiguration = .default
        sync()
    }

    func updateAssistConfiguration(_ config: GestureAssistConfiguration) {
        Current.settingsStore.gestureAssistConfiguration = config
        assistConfiguration = config
    }

    /// Returns true if any gesture is configured to showAssistView
    var hasAssistViewGesture: Bool {
        settings.values.contains(.showAssistView)
    }

    private func sync() {
        settings = Current.settingsStore.gestures
        assistConfiguration = Current.settingsStore.gestureAssistConfiguration
    }
}
