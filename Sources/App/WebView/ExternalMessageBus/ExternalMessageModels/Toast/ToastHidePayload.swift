import Foundation

struct ToastHidePayload: ExternalBusPayload {
    let id: String

    init?(payload: [String: Any]?) {
        guard let payload,
              let id = payload["id"] as? String else {
            return nil
        }
        self.id = id
    }
}
