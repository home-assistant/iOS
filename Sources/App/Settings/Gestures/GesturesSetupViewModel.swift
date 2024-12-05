import Foundation
import Shared

final class GesturesSetupViewModel: ObservableObject {
    @Published var settings: [HAGesture: HAGestureAction] = [:]

    init() {
        self.settings = Current.settingsStore.gestures
    }

    func selection(for gesture: HAGesture) -> HAGestureAction {
        settings[gesture] ?? .none
    }

    func setSelection(for gesture: HAGesture, newValue: HAGestureAction) {
        Current.settingsStore.gestures[gesture] = newValue
        settings = Current.settingsStore.gestures
    }
}
