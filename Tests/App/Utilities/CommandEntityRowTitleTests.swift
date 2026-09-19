@testable import HomeAssistant
@testable import Shared
import Testing

/// Every command's entity type titles its row with what the command does, not with the entity's name
/// alone.
///
/// Spotlight builds one row per App Shortcut per entity and titles each with nothing but the entity's
/// display representation, so while these read as the bare name a single light turned up as a column
/// of identical "Chamber light" rows — one dimming it, one turning it off, one opening the app — with
/// nothing to tell them apart. These are the types that carry a command of their own;
/// `HAAppEntityAppIntentEntity` deliberately stays the bare name, because its row *is* the entity and
/// tapping it opens exactly that.
struct CommandEntityRowTitleTests {
    /// One server, so a context line never depends on the server name.
    private func withOneServer(_ body: () -> Void) {
        let previous = Current.servers
        defer { Current.servers = previous }
        Current.servers = FakeServerManager(initial: 1)
        body()
    }

    @Test func dimmingNamesItself() {
        withOneServer {
            let title = DimmableLightAppEntity(
                id: "s1-light.kitchen",
                entityId: "light.kitchen",
                serverId: "s1",
                serverName: "Cabin",
                displayString: "Ceiling",
                iconName: "mdi:ceiling-light"
            ).displayRepresentation.title

            #expect(String(localized: title) == "Dim Ceiling")
        }
    }

    @Test func settingATemperatureNamesItself() {
        withOneServer {
            let title = ThermostatAppEntity(
                id: "s1-climate.hall",
                entityId: "climate.hall",
                serverId: "s1",
                serverName: "Cabin",
                displayString: "Hallway",
                iconName: "mdi:thermostat"
            ).displayRepresentation.title

            #expect(String(localized: title) == "Set Hallway temperature")
        }
    }

    @Test func openingAndClosingNameThemselves() {
        withOneServer {
            let title = OpenableEntityAppEntity(
                id: "s1-cover.blind",
                entityId: "cover.blind",
                serverId: "s1",
                serverName: "Cabin",
                displayString: "Blind",
                iconName: "mdi:blinds"
            ).displayRepresentation.title

            #expect(String(localized: title) == "Open or close Blind")
        }
    }

    /// The point of the change: two commands over one entity must not produce the same row. Turning on
    /// and turning off still share `ControllableEntityAppEntity`, and so still share a title — a phrase
    /// may name only one parameter, so the direction is fixed by the shortcut and cannot reach here.
    @Test func eachCommandOverOneEntityReadsDifferently() {
        withOneServer {
            let name = "Chamber light"
            let titles = [
                String(localized: ControllableEntityAppEntity(
                    id: "s1-light.chamber",
                    entityId: "light.chamber",
                    serverId: "s1",
                    serverName: "Cabin",
                    displayString: name,
                    iconName: "mdi:lightbulb"
                ).displayRepresentation.title),
                String(localized: ReadableEntityAppEntity(
                    id: "s1-light.chamber",
                    entityId: "light.chamber",
                    serverId: "s1",
                    serverName: "Cabin",
                    displayString: name,
                    iconName: "mdi:lightbulb"
                ).displayRepresentation.title),
                String(localized: DimmableLightAppEntity(
                    id: "s1-light.chamber",
                    entityId: "light.chamber",
                    serverId: "s1",
                    serverName: "Cabin",
                    displayString: name,
                    iconName: "mdi:lightbulb"
                ).displayRepresentation.title),
            ]

            #expect(Set(titles).count == titles.count)
            #expect(titles.allSatisfy { $0 != name })
            #expect(titles.allSatisfy { $0.contains(name) })
        }
    }
}
