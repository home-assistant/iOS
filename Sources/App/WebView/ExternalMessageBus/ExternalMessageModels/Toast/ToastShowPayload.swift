import Foundation

struct ToastShowPayload: ExternalBusPayload {
    let id: String
    let message: String
    let dismissable: Bool
    let duration: Double?

    init?(payload: [String: Any]?) {
        guard let id = payload?["id"] as? String, let message = payload?["message"] as? String else {
            return nil
        }
        self.id = id
        self.message = message
        self.duration = payload?["duration"] as? Double
        self.dismissable = payload?["dismissable"] as? Bool ?? false
    }
}
