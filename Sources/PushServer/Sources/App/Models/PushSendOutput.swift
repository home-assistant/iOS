import Vapor

struct PushSendOutput: Content {
    var target: String
    var messageId: UUID
    var pushType: String
    var collapseIdentifier: String?
    var rateLimits: RateLimitsGetOutput.OutputRateLimits
    var sentPayload: String
}
