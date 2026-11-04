import PromiseKit
import Shared
import SwiftUI

@MainActor
final class NotificationDebugViewModel: ObservableObject {
    // `Self` can't be referenced from a stored-property initializer in a class; use the
    // type name explicitly.
    @Published var pushIDDisplay: String = NotificationDebugViewModel
        .displayForPushID(Current.settingsStore.pushID)

    var pushID: String? { Current.settingsStore.pushID }

    private static func displayForPushID(_ id: String?) -> String {
        id ?? L10n.SettingsDetails.Notifications.PushIdSection.notRegistered
    }

    // PromiseKit also exports a single-parameter `Result`, so qualify with `Swift.Result`.
    func resetPushID(completion: @escaping (Swift.Result<Void, Error>) -> Void) {
        Current.Log.verbose("Resetting push token!")
        firstly {
            Current.notificationManager.resetPushID()
        }.done { [weak self] newToken in
            self?.pushIDDisplay = Self.displayForPushID(newToken)
        }.then { _ in
            when(fulfilled: Current.apis.map { $0.updateRegistration() })
        }.done { _ in
            completion(.success(()))
        }.catch { error in
            Current.Log.error("Error resetting push token: \(error)")
            completion(.failure(error))
        }
    }
}
