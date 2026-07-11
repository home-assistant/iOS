import Foundation
import HANetworking

/// Lets the watch widget refresh its complication values itself, directly from Home Assistant over
/// REST, without waiting for the WatchApp to be woken. This is the piece that makes complications stay
/// fresh in the background: WidgetKit calls the timeline provider on the widget's own budget, and this
/// fetches live values there.
///
/// It reuses the shared `HANetworking` layer end-to-end — `ServerManagerImpl` reads the servers/tokens
/// from the (shared-keychain) store, and `ConnectionInfo.evaluate` handles mTLS / self-signed trust —
/// so there is no duplicated networking. Everything degrades gracefully: if the configs or servers
/// can't be read (e.g. the shared keychain isn't available), it leaves the stored snapshot untouched
/// and the widget renders the last known values.
enum WatchWidgetLiveFetch {
    /// Refresh the configured complication (or all, when `configuredID` is nil), updating the stored
    /// snapshot's value text in the app group. Best-effort; never throws.
    static func refresh(configuredID: String?) async {
        let configs = readConfigs()
        guard !configs.isEmpty else { return }

        let servers = ServerManagerImpl().all
        guard !servers.isEmpty else { return }

        let targets = configuredID.flatMap { id in configs.filter { $0.id == id } } ?? configs
        var updates: [String: String] = [:] // config.id -> fresh value text

        for config in targets where config.kind == .entity {
            guard let entityId = config.entityId,
                  let server = servers.first(where: { $0.identifier.rawValue == config.serverId }),
                  let value = await fetchValue(config: config, entityId: entityId, server: server) else {
                continue
            }
            updates[config.id] = value
        }

        guard !updates.isEmpty else { return }
        applyUpdates(updates)
    }

    // MARK: - Fetch

    private static func fetchValue(
        config: WatchComplicationConfig,
        entityId: String,
        server: Server
    ) async -> String? {
        guard let baseURL = await server.activeURL() else { return nil }
        let token = server.info.token.accessToken
        guard !token.isEmpty else { return nil }

        var request = URLRequest(url: baseURL.appendingPathComponent("api/states/\(entityId)"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Reuse HANetworking's connection TLS handling (mTLS client cert + self-signed exceptions).
        let delegate = ConnectionChallengeDelegate(connection: server.info.connection)
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let state = json["state"] as? String else {
            return nil
        }
        let attributes = json["attributes"] as? [String: Any] ?? [:]

        // Value + unit resolution, mirroring the WatchApp's builder (shared helpers in HAModels).
        let rawValue: String
        let resolvedUnit: String?
        if let attribute = config.valueAttribute {
            rawValue = attributes[attribute].map { String(describing: $0) } ?? state
            resolvedUnit = WatchComplicationConfig.attributeUnit(
                attribute: attribute,
                attributes: attributes,
                domain: entityId.components(separatedBy: ".").first
            )
        } else {
            rawValue = state
            resolvedUnit = attributes["unit_of_measurement"] as? String
        }
        let effectiveUnit = config.unitOverride.flatMap { $0.isEmpty ? nil : $0 } ?? resolvedUnit
        let unit = config.showsUnit() ? effectiveUnit : nil
        return format(rawValue, unit: unit, precision: config.valuePrecision)
    }

    private static func format(_ value: String, unit: String?, precision: Int?) -> String {
        var text = value
        if let precision, let number = Double(value) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = precision
            formatter.maximumFractionDigits = precision
            text = formatter.string(from: NSNumber(value: number)) ?? value
        }
        if let unit, !unit.isEmpty {
            text += " \(unit)"
        }
        return text
    }

    // MARK: - App-group persistence

    private static func readConfigs() -> [WatchComplicationConfig] {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WatchWidgetConstants.appGroupID) else {
            return []
        }
        let dbURL = container.appendingPathComponent("databases/App.sqlite")
        guard FileManager.default.fileExists(atPath: dbURL.path) else { return [] }
        var config = Configuration()
        config.readonly = true
        guard let queue = try? DatabaseQueue(path: dbURL.path, configuration: config) else { return [] }
        return (try? queue.read { db in
            try WatchComplicationConfig.fetchAll(db)
        }) ?? []
    }

    private static func applyUpdates(_ updates: [String: String]) {
        guard let defaults = UserDefaults(suiteName: WatchWidgetConstants.appGroupID),
              let data = defaults.data(forKey: WatchWidgetConstants.defaultsKey),
              var snapshots = try? JSONDecoder().decode([WatchWidgetComplicationSnapshot].self, from: data) else {
            return
        }
        for index in snapshots.indices {
            guard let id = snapshots[index].id, let value = updates[id] else { continue }
            let name = snapshots[index].menuName ?? snapshots[index].subtitle
            snapshots[index].title = value
            snapshots[index].inlineText = [name, value].filter { !$0.isEmpty }.joined(separator: " ")
        }
        if let encoded = try? JSONEncoder().encode(snapshots) {
            defaults.set(encoded, forKey: WatchWidgetConstants.defaultsKey)
        }
    }
}

/// Minimal URLSession delegate that routes TLS challenges through the server's `ConnectionInfo`
/// (mTLS client certificate + self-signed trust exceptions), reusing HANetworking's logic.
private final class ConnectionChallengeDelegate: NSObject, URLSessionDelegate {
    private let connection: ConnectionInfo
    init(connection: ConnectionInfo) { self.connection = connection }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let (disposition, credential) = connection.evaluate(challenge)
        completionHandler(disposition, credential)
    }
}
