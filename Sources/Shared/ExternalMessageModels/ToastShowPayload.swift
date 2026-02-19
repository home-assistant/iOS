import Foundation

public struct ToastShowPayload: ExternalBusPayload {
    public let id: String
    public let message: String
    public let dismissable: Bool
    public let duration: Double?

    public init?(payload: [String: Any]?) {
        guard let id = payload?["id"] as? String, let message = payload?["message"] as? String else {
            return nil
        }
        self.id = id
        self.message = message
        self.duration = payload?["duration"] as? Double
        self.dismissable = payload?["dismissable"] as? Bool ?? false
    }
}
