import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

/// How discovery turns an advertised Home Assistant service into an instance for the servers list.
/// Services are built locally with their TXT record set, so nothing is browsed or resolved on the
/// network.
@MainActor
struct BonjourTests {
    private final class RecordingObserver: BonjourObserver {
        var added: [DiscoveredHomeAssistant] = []
        var removed: [String] = []

        func bonjour(_ bonjour: Bonjour, didAdd instance: DiscoveredHomeAssistant) {
            added.append(instance)
        }

        func bonjour(_ bonjour: Bonjour, didRemoveInstanceWithName name: String) {
            removed.append(name)
        }
    }

    private func service(named name: String, txt: [String: String]?) -> NetService {
        let service = NetService(domain: "local.", type: "_home-assistant._tcp.", name: name, port: 8123)
        if let txt {
            service.setTXTRecord(NetService.data(fromTXTRecord: txt.mapValues { Data($0.utf8) }))
        }
        return service
    }

    @Test func aResolvedServiceIsAddedWithItsAddressesAndName() throws {
        let bonjour = Bonjour()
        let observer = RecordingObserver()
        bonjour.observer = observer

        bonjour.netServiceDidResolveAddress(service(named: "Chalet", txt: [
            "uuid": "abc123",
            "version": "2026.10.0",
            "internal_url": "http://192.0.2.10:8123",
            "external_url": "https://chalet.example.com",
            "location_name": "Chalet",
        ]))

        let instance = try #require(observer.added.first)
        #expect(instance.bonjourName == "Chalet")
        #expect(instance.locationName == "Chalet")
        #expect(instance.internalURL?.absoluteString == "http://192.0.2.10:8123")
        #expect(instance.externalURL?.absoluteString == "https://chalet.example.com")
    }

    @Test func aServiceWithoutALocationNameIsNamedAfterItself() throws {
        let bonjour = Bonjour()
        let observer = RecordingObserver()
        bonjour.observer = observer

        bonjour.netServiceDidResolveAddress(service(named: "Old Home", txt: [
            "uuid": "def456",
            "base_url": "http://192.0.2.20:8123",
        ]))

        let instance = try #require(observer.added.first)
        #expect(instance.locationName == "Old Home")
        #expect(instance.externalURL?.absoluteString == "http://192.0.2.20:8123")
    }

    @Test func aServiceWithoutAnAddressIsSkipped() {
        let bonjour = Bonjour()
        let observer = RecordingObserver()
        bonjour.observer = observer

        bonjour.netServiceDidResolveAddress(service(named: "No address", txt: ["uuid": "ghi789"]))

        #expect(observer.added.isEmpty)
    }

    @Test func aRemovedServiceIsReported() {
        let bonjour = Bonjour()
        let observer = RecordingObserver()
        bonjour.observer = observer

        bonjour.netServiceBrowser(NetServiceBrowser(), didRemove: service(named: "Chalet", txt: nil), moreComing: false)

        #expect(observer.removed == ["Chalet"])
    }

    @Test func stoppingWithoutStartingDoesNothing() {
        let bonjour = Bonjour()
        bonjour.stop()
        #expect(bonjour.observer == nil)
    }
}
