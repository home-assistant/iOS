import APNS
import APNSwift
import Foundation
import Redis
import SharedPush
import Vapor

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

    if let server = Environment.get("REDIS_SERVER") {
        app.logger.notice("using redis server for rate limits")
        app.redis.configuration = try RedisConfiguration(
            hostname: server,
            password: Environment.get("REDIS_PASSWORD"),
            pool: .init(
                maximumConnectionCount: .maximumPreservedConnections(6),
                connectionRetryTimeout: .seconds(60)
            )
        )
        app.rateLimits.cache = app.caches.redis
    } else {
        app.logger.notice("using in-memory for rate limits")
        app.rateLimits.cache = app.caches.memory
    }

    app.legacyNotificationParser.parser = LegacyNotificationParserImpl(pushSource: "apns-vapor")

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
