import Foundation

struct ToastShowPayload: ExternalBusPayload {
    enum DisplayType: String {
        case permanent
        case timeout
        case unknown

        init(rawValue: String) {
            switch rawValue {
            case "permanent":
                self = .permanent
            case "timeout":
                self = .timeout
            default:
                self = .unknown
            }
        }
    }

    let id: String
    let displayType: DisplayType
    let title: String
    let body: String
    let icon: String?
    let seconds: Double?

    init?(payload: [String: Any]?) {
        guard let payload,
              let id = payload["id"] as? String,
              let displayTypeString = payload["display_type"] as? String,
              let title = payload["title"] as? String,
              let body = payload["body"] as? String else {
            return nil
        }

        let displayType = DisplayType(rawValue: displayTypeString)
        let seconds = payload["seconds"] as? Double

        // Validate that timeout display type has seconds
        if displayType == .timeout, seconds == nil {
            return nil
        }

        self.id = id
        self.displayType = displayType
        self.title = title
        self.body = body
        self.icon = payload["icon"] as? String
        self.seconds = seconds
    }
}
