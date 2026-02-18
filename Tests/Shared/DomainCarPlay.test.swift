import Foundation
@testable import Shared
import Testing

@Suite("Domain CarPlay Tests")
struct DomainCarPlayTests {
    // MARK: - CarPlay Support Tests
    
    @Test("IsCarPlaySupported for supported domains")
    func isCarPlaySupportedTrue() {
        #expect(Domain.automation.isCarPlaySupported == true)
        #expect(Domain.button.isCarPlaySupported == true)
        #expect(Domain.cover.isCarPlaySupported == true)
        #expect(Domain.fan.isCarPlaySupported == true)
        #expect(Domain.inputBoolean.isCarPlaySupported == true)
        #expect(Domain.inputButton.isCarPlaySupported == true)
        #expect(Domain.light.isCarPlaySupported == true)
        #expect(Domain.lock.isCarPlaySupported == true)
        #expect(Domain.scene.isCarPlaySupported == true)
        #expect(Domain.script.isCarPlaySupported == true)
        #expect(Domain.switch.isCarPlaySupported == true)
    }
    
    @Test("IsCarPlaySupported for unsupported domains")
    func isCarPlaySupportedFalse() {
        #expect(Domain.sensor.isCarPlaySupported == false)
        #expect(Domain.binarySensor.isCarPlaySupported == false)
        #expect(Domain.zone.isCarPlaySupported == false)
        #expect(Domain.person.isCarPlaySupported == false)
        #expect(Domain.camera.isCarPlaySupported == false)
        #expect(Domain.todo.isCarPlaySupported == false)
    }
    
    @Test("CarPlaySupportedDomains contains expected domains")
    func carPlaySupportedDomainsContent() {
        let supportedDomains = Domain.automation.carPlaySupportedDomains
        
        #expect(supportedDomains.contains(.automation))
        #expect(supportedDomains.contains(.button))
        #expect(supportedDomains.contains(.cover))
        #expect(supportedDomains.contains(.fan))
        #expect(supportedDomains.contains(.inputBoolean))
        #expect(supportedDomains.contains(.inputButton))
        #expect(supportedDomains.contains(.light))
        #expect(supportedDomains.contains(.lock))
        #expect(supportedDomains.contains(.scene))
        #expect(supportedDomains.contains(.script))
        #expect(supportedDomains.contains(.switch))
        
        // Verify count matches expected
        #expect(supportedDomains.count == 11)
    }
    
    @Test("CarPlaySupportedDomains does not contain unsupported domains")
    func carPlaySupportedDomainsExclusions() {
        let supportedDomains = Domain.automation.carPlaySupportedDomains
        
        #expect(!supportedDomains.contains(.sensor))
        #expect(!supportedDomains.contains(.binarySensor))
        #expect(!supportedDomains.contains(.zone))
        #expect(!supportedDomains.contains(.person))
        #expect(!supportedDomains.contains(.camera))
        #expect(!supportedDomains.contains(.todo))
    }
    
    @Test("CarPlaySupportedDomains is consistent across instances")
    func carPlaySupportedDomainsConsistency() {
        let domains1 = Domain.light.carPlaySupportedDomains
        let domains2 = Domain.switch.carPlaySupportedDomains
        let domains3 = Domain.scene.carPlaySupportedDomains
        
        // All instances should return the same list
        #expect(domains1.count == domains2.count)
        #expect(domains2.count == domains3.count)
        #expect(Set(domains1) == Set(domains2))
        #expect(Set(domains2) == Set(domains3))
    }
    
    // MARK: - Domain Initialization Tests
    
    @Test("Domain initialization from entity ID for CarPlay supported domains")
    func domainInitFromEntityIdSupported() {
        #expect(Domain(entityId: "automation.test") == .automation)
        #expect(Domain(entityId: "button.doorbell") == .button)
        #expect(Domain(entityId: "cover.garage") == .cover)
        #expect(Domain(entityId: "fan.bedroom") == .fan)
        #expect(Domain(entityId: "input_boolean.test") == .inputBoolean)
        #expect(Domain(entityId: "input_button.test") == .inputButton)
        #expect(Domain(entityId: "light.living_room") == .light)
        #expect(Domain(entityId: "lock.front_door") == .lock)
        #expect(Domain(entityId: "scene.movie_night") == .scene)
        #expect(Domain(entityId: "script.automation") == .script)
        #expect(Domain(entityId: "switch.kitchen") == .switch)
    }
    
    @Test("Domain initialization from entity ID for unsupported domains")
    func domainInitFromEntityIdUnsupported() {
        #expect(Domain(entityId: "sensor.temperature") == .sensor)
        #expect(Domain(entityId: "binary_sensor.motion") == .binarySensor)
        #expect(Domain(entityId: "zone.home") == .zone)
        #expect(Domain(entityId: "person.john") == .person)
        #expect(Domain(entityId: "camera.front_door") == .camera)
        #expect(Domain(entityId: "todo.shopping") == .todo)
    }
    
    @Test("Domain initialization from invalid entity ID")
    func domainInitFromInvalidEntityId() {
        #expect(Domain(entityId: "invalid") == nil)
        #expect(Domain(entityId: "") == nil)
        #expect(Domain(entityId: ".test") == nil)
        #expect(Domain(entityId: "test.") == nil)
        #expect(Domain(entityId: "unknown_domain.test") == nil)
    }
    
    // MARK: - Integration Tests
    
    @Test("All CarPlay supported domains have valid raw values")
    func carPlayDomainsHaveValidRawValues() {
        let supportedDomains = Domain.light.carPlaySupportedDomains
        
        for domain in supportedDomains {
            #expect(!domain.rawValue.isEmpty, "Domain \(domain) should have non-empty raw value")
        }
    }
    
    @Test("All CarPlay supported domains can be initialized from raw value")
    func carPlayDomainsCanBeInitializedFromRawValue() {
        let supportedDomains = Domain.light.carPlaySupportedDomains
        
        for domain in supportedDomains {
            let reinitializedDomain = Domain(rawValue: domain.rawValue)
            #expect(reinitializedDomain == domain, "Domain \(domain) should be reinitializable from its raw value")
        }
    }
    
    @Test("CarPlay supported domains are subset of all domains")
    func carPlayDomainsAreSubsetOfAll() {
        let supportedDomains = Set(Domain.light.carPlaySupportedDomains)
        let allDomains = Set(Domain.allCases)
        
        #expect(supportedDomains.isSubset(of: allDomains), "CarPlay supported domains should be a subset of all domains")
    }
    
    @Test("CarPlay supported domains have localized descriptions")
    func carPlayDomainsHaveLocalizedDescriptions() {
        let supportedDomains = Domain.light.carPlaySupportedDomains
        
        for domain in supportedDomains {
            let description = domain.localizedDescription
            #expect(!description.isEmpty, "Domain \(domain) should have localized description")
        }
    }
    
    @Test("CarPlay supported domains have valid icons")
    func carPlayDomainsHaveValidIcons() {
        let supportedDomains = Domain.light.carPlaySupportedDomains
        
        for domain in supportedDomains {
            let icon = domain.icon()
            #expect(!icon.name.isEmpty, "Domain \(domain) should have valid icon")
        }
    }
}
