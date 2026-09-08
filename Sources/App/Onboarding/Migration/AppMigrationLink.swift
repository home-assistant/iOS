import Foundation

/// The URLs the two apps exchange. The key travels only in the request URL, which iOS delivers to
/// the one app registered for the scheme, never through the pasteboard.
enum AppMigrationLink: Equatable {
    static let host = "migration"

    /// New app → previous app: please package your setup for this session.
    case request(AppMigrationSession)
    /// Previous app → new app: the sealed payload is on the pasteboard. The key rides along only when
    /// the previous app started the transfer itself and the new app has no session to match it to.
    case payloadReady(sessionID: UUID, key: String?)
    /// Previous app → new app: the user cancelled.
    case declined(sessionID: UUID)
    /// Previous app → new app: drop everything you received and ask for the setup again.
    case restart

    init?(url: URL) {
        guard url.host?.lowercased() == Self.host,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        if components.path == "/restart" {
            self = .restart
            return
        }
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
        guard let sessionID = query["session"].flatMap(UUID.init(uuidString:)) else { return nil }
        switch components.path {
        case "/request":
            guard let keyString = query["key"],
                  let session = AppMigrationSession(id: sessionID, keyString: keyString) else { return nil }
            self = .request(session)
        case "/payload":
            self = .payloadReady(sessionID: sessionID, key: query["key"])
        case "/declined":
            self = .declined(sessionID: sessionID)
        default:
            return nil
        }
    }

    func url(to role: AppMigrationRole) -> URL {
        var components = URLComponents()
        components.scheme = role.urlScheme
        components.host = Self.host
        switch self {
        case let .request(session):
            components.path = "/request"
            components.queryItems = [
                URLQueryItem(name: "session", value: session.id.uuidString),
                URLQueryItem(name: "key", value: session.keyString),
            ]
        case let .payloadReady(sessionID, key):
            components.path = "/payload"
            components.queryItems = [URLQueryItem(name: "session", value: sessionID.uuidString)]
            if let key {
                components.queryItems?.append(URLQueryItem(name: "key", value: key))
            }
        case let .declined(sessionID):
            components.path = "/declined"
            components.queryItems = [URLQueryItem(name: "session", value: sessionID.uuidString)]
        case .restart:
            components.path = "/restart"
        }
        return components.url!
    }
}
