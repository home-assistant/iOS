import Vapor

struct PushSendOutput: Content {
    var sentPayload: String
    var pushType: String
    var collapseIdentifier: String?
}
