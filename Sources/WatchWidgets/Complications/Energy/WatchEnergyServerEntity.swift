import AppIntents
import HAWatchComplications

/// One server the app can summarise energy for, as the complication picker lists it.
///
/// The list is whatever the watch app last wrote to the app group, so it grows and shrinks with the
/// servers the user has — which is what makes the energy complication "one per server" without
/// anyone configuring anything.
@available(watchOS 10.0, *)
struct WatchEnergyServerEntity: AppEntity, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Server")
    static let defaultQuery = WatchEnergyServerEntityQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: .init(stringLiteral: name))
    }

    init(snapshot: EnergyComplicationSnapshot) {
        self.id = snapshot.serverId
        self.name = snapshot.serverName
    }
}
