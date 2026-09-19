import Foundation

/// One server's energy summary, as the watch app last managed to read it, ready for the face.
///
/// The watch app is the only process that can build this: energy preferences and long-term
/// statistics are websocket commands, and the watch widget extension deliberately links nothing
/// heavier than `URLSession`. So the app fetches, resolves and formats, then leaves the finished
/// payload in the shared app group for the extension to draw — the same arrangement the entity
/// complications use, and the reason a complication keeps its last values when the app isn't woken.
///
/// One snapshot per server, which is what makes the complication list on the face grow and shrink
/// with the servers the app has.
public struct EnergyComplicationSnapshot: Codable, Equatable, Sendable, Identifiable {
    /// App-group `UserDefaults` key the array is stored under.
    public static let defaultsKey = "watchEnergyComplicationSnapshots"

    public var id: String { serverId }

    /// Matches `Server.identifier.rawValue`.
    public let serverId: String
    public let serverName: String
    /// When the app last built this payload, so the face can tell a value apart from a stale one.
    public let date: Date
    /// The period's headline figures, in the order they are drawn.
    public let stats: [EnergyComplicationStat]
    /// The period's buckets, already split into what the chart paints.
    public let bars: [EnergyComplicationChartBar]
    /// What to say instead of the figures and the chart — a server with no energy dashboard, or one
    /// that couldn't be reached. Localised by the app, which owns the strings; nil when there is
    /// something to draw.
    public let message: String?

    public init(
        serverId: String,
        serverName: String,
        date: Date,
        stats: [EnergyComplicationStat] = [],
        bars: [EnergyComplicationChartBar] = [],
        message: String? = nil
    ) {
        self.serverId = serverId
        self.serverName = serverName
        self.date = date
        self.stats = stats
        self.bars = bars
        self.message = message
    }

    /// Whether the payload has anything to show. A message-only snapshot still belongs in the store:
    /// it is what keeps the server's complication in the picker while its dashboard is unreachable.
    public var hasContent: Bool {
        !stats.isEmpty || bars.contains { !$0.isEmpty }
    }

    /// Persist the full set of per-server snapshots. Best-effort: a store that can't be written
    /// leaves the face showing whatever it already had.
    public static func write(_ snapshots: [Self], to defaults: UserDefaults?) {
        guard let defaults else { return }
        // Sorted keys so equal payloads encode to identical bytes, which is what lets a caller skip
        // a WidgetKit reload it doesn't need.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(snapshots) {
            defaults.set(data, forKey: defaultsKey)
        }
    }

    /// Read the stored per-server snapshots (empty when absent or undecodable).
    public static func read(from defaults: UserDefaults?) -> [Self] {
        guard let defaults, let data = defaults.data(forKey: defaultsKey),
              let snapshots = try? JSONDecoder().decode([Self].self, from: data) else {
            return []
        }
        return snapshots
    }
}
