import Vapor

struct RateLimitsGetOutput: Content {
    enum CodingKeys: String, CodingKey {
        case target = "target"
        case rateLimits = "rate_limits"
    }

    struct OutputRateLimits: Content {
        var successful: Int
        var errors: Int
        var maximum: Int
        var remaining: Int {
            maximum - (successful + errors)
        }

        var resetsAt: Date
    }

    var target: String
    var rateLimits: OutputRateLimits
}
