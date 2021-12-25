import Vapor

class RateLimitsController {
    func check(req: Request) async throws -> RateLimitsGetOutput {
        try RateLimitsGetInput.validate(content: req)
        let input = try req.content.decode(RateLimitsGetInput.self)
        let rateLimits = try await req.application.rateLimits.rateLimit(for: input.pushToken)
        return .init(
            target: input.pushToken,
            rateLimits: .init(
                successful: rateLimits.successful,
                errors: rateLimits.errors,
                maximum: RateLimitsValues.dailyMaximum,
                resetsAt: await req.application.rateLimits.expirationDate(for: input.pushToken)
            )
        )
    }
}
