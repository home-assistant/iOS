import APNS
import APNSwift
import Foundation
import Vapor

public func configure(_ app: Application) throws {
    app.apns.configuration = try .init(
        authenticationMethod: .jwt(
            key: .private(pem: Environment.get("APNS_KEY_CONTENTS")!),
            keyIdentifier: .init(string: Environment.get("APNS_KEY_IDENTIFIER")!),
            teamIdentifier: Environment.get("APNS_KEY_TEAM_IDENTIFIER")!
        ),
        topic: Environment.get("APNS_TOPIC")!,
        environment: app.environment.apnSwiftEnvironment
    )

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
