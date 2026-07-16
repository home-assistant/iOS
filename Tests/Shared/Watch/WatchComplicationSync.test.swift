import Foundation
@testable import Shared
import Testing

/// Tests for the watch complication sync additions: the proactive mirror-push constants/reasons, the
/// frontend-parity attribute unit resolution, the config value/precision/unit fields, and the mirror
/// retain semantics.
@Suite("Watch complication sync")
struct WatchComplicationSyncTests {
    // MARK: - Constants

    @Test("Mirror push blob identifier is stable")
    func blobIdentifier() {
        #expect(WatchDatabaseMirror.blobIdentifier == "watchDatabaseMirror.push")
    }

    #if os(iOS)
    @Test("Mirror push debounce interval")
    func debounceInterval() {
        #expect(WatchMirrorPushCoordinator.debounceInterval == 3)
    }

    @Test("Mirror push reasons expose stable raw values and descriptions")
    func reasons() {
        #expect(Set(WatchMirrorPushCoordinator.Reason.allCases.map(\.rawValue)) == [
            "databaseUpdated", "complicationChanged", "serversChanged",
        ])
        #expect(WatchMirrorPushCoordinator.Reason.databaseUpdated.logDescription == "database updated")
        #expect(WatchMirrorPushCoordinator.Reason.complicationChanged.logDescription == "complication changed")
        #expect(WatchMirrorPushCoordinator.Reason.serversChanged.logDescription == "servers changed")
    }
    #endif

    // MARK: - attributeUnit (Home Assistant frontend parity)

    @Test("Attribute unit uses the sibling <attr>_unit attribute (weather)")
    func attributeUnitWeatherSibling() {
        let attributes: [String: Any] = ["temperature": 22, "temperature_unit": "°C"]
        #expect(
            WatchComplicationConfig.attributeUnit(attribute: "temperature", attributes: attributes, domain: "weather")
                == "°C"
        )
    }

    @Test("Attribute unit falls back to the domain map")
    func attributeUnitDomainMap() {
        #expect(
            WatchComplicationConfig.attributeUnit(attribute: "current_position", attributes: [:], domain: "cover")
                == "%"
        )
        #expect(
            WatchComplicationConfig.attributeUnit(attribute: "color_temp_kelvin", attributes: [:], domain: "light")
                == "K"
        )
    }

    @Test("Attribute unit is nil for unknown attributes and never uses the state unit")
    func attributeUnitNil() {
        let attributes: [String: Any] = ["unit_of_measurement": "W", "foo": 1]
        #expect(
            WatchComplicationConfig.attributeUnit(attribute: "foo", attributes: attributes, domain: "sensor") == nil
        )
    }

    // MARK: - Config round-trip

    @Test("Config round-trips the value source / precision / unit override fields")
    func configRoundTrip() throws {
        var config = WatchComplicationConfig(serverId: "s1")
        config.valueAttribute = "temperature"
        config.valuePrecision = 1
        config.unitOverride = "°F"
        let decoded = try JSONDecoder().decode(
            WatchComplicationConfig.self,
            from: JSONEncoder().encode(config)
        )
        #expect(decoded.valueAttribute == "temperature")
        #expect(decoded.valuePrecision == 1)
        #expect(decoded.unitOverride == "°F")
    }

    // MARK: - Mirror retain semantics

    @Test("Nil complications round-trip as nil (retain); empty arrays stay authoritative")
    func mirrorRetainSemantics() throws {
        let retain = WatchDatabaseMirror(entities: [], areas: [], pipelines: [])
        let retainDecoded = try WatchDatabaseMirror.decodeForWatchThrowing(retain.encodeForWatch())
        #expect(retainDecoded.complications == nil)
        #expect(retainDecoded.complicationConfigs == nil)

        let authoritative = WatchDatabaseMirror(
            entities: [],
            areas: [],
            pipelines: [],
            complications: [],
            complicationConfigs: []
        )
        let authDecoded = try WatchDatabaseMirror.decodeForWatchThrowing(authoritative.encodeForWatch())
        #expect(authDecoded.complications == [])
        #expect(authDecoded.complicationConfigs == [])
    }
}
