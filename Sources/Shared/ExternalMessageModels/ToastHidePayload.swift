import Foundation

public struct ToastHidePayload: ExternalBusPayload {
    public let id: String

    public init?(payload: [String: Any]?) {
        guard let payload,
              let id = payload["id"] as? String else {
            return nil
        }
        self.id = id
    }
}
