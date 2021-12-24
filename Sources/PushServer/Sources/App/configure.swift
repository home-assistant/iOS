import APNS
import APNSwift
import Foundation
import SharedPush
import Vapor
import Redis

public func configure(_ app: Application) throws {
    if app.environment == .testing {
    } else {
        app.apns.configuration = try .init(
            authenticationMethod: .jwt(
                key: .private(pem: Environment.get("APNS_KEY_CONTENTS")!),
                keyIdentifier: .init(string: Environment.get("APNS_KEY_IDENTIFIER")!),
                teamIdentifier: Environment.get("APNS_KEY_TEAM_IDENTIFIER")!
            ),
            topic: Environment.get("APNS_TOPIC")!,
            environment: app.environment.apnSwiftEnvironment,
            logger: app.logger,
            timeout: .seconds(10)
        )
    }

    app.redis.configuration = try RedisConfiguration(
        hostname: Environment.get("REDIS_SERVER") ?? "localhost",
        password: Environment.get("REDIS_PASSWORD")
    )

    app.legacyNotificationParser.parser = LegacyNotificationParserImpl(pushSource: "apns-vapor")
    app.rateLimits.rateLimits = RateLimitsImpl(cache: app.caches.redis)

    // register routes
    try routes(app)
}

extension Environment {
    var apnSwiftEnvironment: APNSwiftConfiguration.Environment {
        switch self {
        case .production: return .production
        default: return .sandbox
        }
    }
}
