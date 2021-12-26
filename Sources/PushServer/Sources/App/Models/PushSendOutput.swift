import Vapor

struct PushSendOutput: Content {
    var sentPayload: String
    var pushType: String
    var target: String
    var collapseIdentifier: String?
    var rateLimits: RateLimitsValues
}
