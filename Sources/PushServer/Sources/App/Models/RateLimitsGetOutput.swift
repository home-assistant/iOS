import Vapor

struct RateLimitsGetOutput: Content {
    enum CodingKeys: String, CodingKey {
        case target = "target"
        case rateLimits = "rate_limits"
    }

    struct OutputRateLimits: Content {
        enum CodingKeys: String, CodingKey {
            case successful
            case errors
            case maximum
            case remaining
            case resetsAt = "resets_at"
        }

        var successful: Int
        var errors: Int
        var maximum: Int
        var remaining: Int {
            maximum - (successful + errors)
        }

        var resetsAt: Date

        init(rateLimits: RateLimitsValues, resetsAt: Date) {
            self.successful = rateLimits.successful
            self.errors = rateLimits.errors
            self.maximum = RateLimitsValues.dailyMaximum
            self.resetsAt = resetsAt
        }

        init(successful: Int, errors: Int, maximum: Int, resetsAt: Date) {
            self.successful = successful
            self.errors = errors
            self.maximum = maximum
            self.resetsAt = resetsAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.successful = try container.decode(Int.self, forKey: .successful)
            self.errors = try container.decode(Int.self, forKey: .errors)
            self.maximum = try container.decode(Int.self, forKey: .maximum)
            self.resetsAt = try container.decode(Date.self, forKey: .resetsAt)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(successful, forKey: .successful)
            try container.encode(errors, forKey: .errors)
            try container.encode(maximum, forKey: .maximum)
            try container.encode(remaining, forKey: .remaining)
            try container.encode(resetsAt, forKey: .resetsAt)
        }
    }

    var target: String
    var rateLimits: OutputRateLimits
}
