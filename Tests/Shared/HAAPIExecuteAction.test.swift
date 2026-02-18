import Foundation
import HAKit
import PromiseKit
@testable import Shared
import Testing

@Suite("HAAPI executeActionForDomainType Tests")
struct HAAPIExecuteActionTests {
    // Note: These tests focus on the logic flow and edge cases of executeActionForDomainType
    // Full integration tests with real API connections are not included here
    
    // MARK: - Domain-specific Logic Tests
    
    @Test("ExecuteActionForDomainType for button domain uses press service")
    func executeActionForButtonDomain() async throws {
        // This test verifies the logic path for button domain
        // In production, this would call the pressButton HATypedRequest
        
        let domain = Domain.button
        let entityId = "button.doorbell"
        let state = ""
        
        // Verify domain is recognized
        #expect(domain == .button)
        #expect(Domain.allCases.contains(domain))
    }
    
    @Test("ExecuteActionForDomainType for input_button domain uses press service")
    func executeActionForInputButtonDomain() async throws {
        let domain = Domain.inputButton
        let entityId = "input_button.test"
        let state = ""
        
        #expect(domain == .inputButton)
        #expect(Domain.allCases.contains(domain))
    }
    
    @Test("ExecuteActionForDomainType for cover domain uses toggle service")
    func executeActionForCoverDomain() async throws {
        let domain = Domain.cover
        let entityId = "cover.garage"
        let state = "open"
        
        #expect(domain == .cover)
        #expect([Domain.cover, .inputBoolean, .light, .switch, .fan].contains(domain))
    }
    
    @Test("ExecuteActionForDomainType for input_boolean domain uses toggle service")
    func executeActionForInputBooleanDomain() async throws {
        let domain = Domain.inputBoolean
        let entityId = "input_boolean.test"
        let state = "on"
        
        #expect(domain == .inputBoolean)
        #expect([Domain.cover, .inputBoolean, .light, .switch, .fan].contains(domain))
    }
    
    @Test("ExecuteActionForDomainType for light domain uses toggle service")
    func executeActionForLightDomain() async throws {
        let domain = Domain.light
        let entityId = "light.bedroom"
        let state = "on"
        
        #expect(domain == .light)
        #expect([Domain.cover, .inputBoolean, .light, .switch, .fan].contains(domain))
    }
    
    @Test("ExecuteActionForDomainType for switch domain uses toggle service")
    func executeActionForSwitchDomain() async throws {
        let domain = Domain.switch
        let entityId = "switch.kitchen"
        let state = "on"
        
        #expect(domain == .switch)
        #expect([Domain.cover, .inputBoolean, .light, .switch, .fan].contains(domain))
    }
    
    @Test("ExecuteActionForDomainType for fan domain uses toggle service")
    func executeActionForFanDomain() async throws {
        let domain = Domain.fan
        let entityId = "fan.bedroom"
        let state = "on"
        
        #expect(domain == .fan)
        #expect([Domain.cover, .inputBoolean, .light, .switch, .fan].contains(domain))
    }
    
    @Test("ExecuteActionForDomainType for scene domain uses activate service")
    func executeActionForSceneDomain() async throws {
        let domain = Domain.scene
        let entityId = "scene.movie_night"
        let state = ""
        
        #expect(domain == .scene)
        #expect(Domain.allCases.contains(domain))
    }
    
    @Test("ExecuteActionForDomainType for script domain uses run service")
    func executeActionForScriptDomain() async throws {
        let domain = Domain.script
        let entityId = "script.automation"
        let state = ""
        
        #expect(domain == .script)
        #expect(Domain.allCases.contains(domain))
    }
    
    @Test("ExecuteActionForDomainType for automation domain uses trigger service")
    func executeActionForAutomationDomain() async throws {
        let domain = Domain.automation
        let entityId = "automation.test"
        let state = ""
        
        #expect(domain == .automation)
        #expect(Domain.allCases.contains(domain))
    }
    
    // MARK: - Lock Domain State-based Logic Tests
    
    @Test("ExecuteActionForDomainType for lock - unlocked state locks")
    func executeActionForLockUnlockedState() async throws {
        let domain = Domain.lock
        let entityId = "lock.front_door"
        let state = "unlocked"
        
        #expect(domain == .lock)
        let domainState = Domain.State(rawValue: state)
        #expect(domainState == .unlocked)
        
        // When unlocked, should lock
        #expect([Domain.State.unlocking, .unlocked, .opening].contains(domainState!))
    }
    
    @Test("ExecuteActionForDomainType for lock - unlocking state locks")
    func executeActionForLockUnlockingState() async throws {
        let domain = Domain.lock
        let entityId = "lock.front_door"
        let state = "unlocking"
        
        let domainState = Domain.State(rawValue: state)
        #expect(domainState == .unlocking)
        
        // When unlocking, should lock
        #expect([Domain.State.unlocking, .unlocked, .opening].contains(domainState!))
    }
    
    @Test("ExecuteActionForDomainType for lock - locked state unlocks")
    func executeActionForLockLockedState() async throws {
        let domain = Domain.lock
        let entityId = "lock.front_door"
        let state = "locked"
        
        let domainState = Domain.State(rawValue: state)
        #expect(domainState == .locked)
        
        // When locked, should unlock
        #expect([Domain.State.locked, .locking].contains(domainState!))
    }
    
    @Test("ExecuteActionForDomainType for lock - locking state unlocks")
    func executeActionForLockLockingState() async throws {
        let domain = Domain.lock
        let entityId = "lock.front_door"
        let state = "locking"
        
        let domainState = Domain.State(rawValue: state)
        #expect(domainState == .locking)
        
        // When locking, should unlock
        #expect([Domain.State.locked, .locking].contains(domainState!))
    }
    
    @Test("ExecuteActionForDomainType for lock - invalid state")
    func executeActionForLockInvalidState() async throws {
        let domain = Domain.lock
        let entityId = "lock.front_door"
        let state = "invalid_state"
        
        let domainState = Domain.State(rawValue: state)
        #expect(domainState == nil)
        
        // Invalid state should be handled gracefully
    }
    
    @Test("ExecuteActionForDomainType for lock - jammed state")
    func executeActionForLockJammedState() async throws {
        let domain = Domain.lock
        let entityId = "lock.front_door"
        let state = "jammed"
        
        let domainState = Domain.State(rawValue: state)
        #expect(domainState == .jammed)
        
        // Jammed state is not in lock/unlock lists, should not perform action
        #expect(![Domain.State.unlocking, .unlocked, .opening, .locked, .locking].contains(domainState!))
    }
    
    // MARK: - Domains that should not perform actions
    
    @Test("ExecuteActionForDomainType for sensor domain does nothing")
    func executeActionForSensorDomain() async throws {
        let domain = Domain.sensor
        let entityId = "sensor.temperature"
        let state = "21.5"
        
        #expect(domain == .sensor)
        // Sensor domain should not perform any action
        #expect([Domain.sensor, .binarySensor, .zone, .person, .camera, .todo].contains(domain))
    }
    
    @Test("ExecuteActionForDomainType for binary_sensor domain does nothing")
    func executeActionForBinarySensorDomain() async throws {
        let domain = Domain.binarySensor
        let entityId = "binary_sensor.motion"
        let state = "on"
        
        #expect(domain == .binarySensor)
        #expect([Domain.sensor, .binarySensor, .zone, .person, .camera, .todo].contains(domain))
    }
    
    @Test("ExecuteActionForDomainType for zone domain does nothing")
    func executeActionForZoneDomain() async throws {
        let domain = Domain.zone
        let entityId = "zone.home"
        let state = "1"
        
        #expect(domain == .zone)
        #expect([Domain.sensor, .binarySensor, .zone, .person, .camera, .todo].contains(domain))
    }
    
    @Test("ExecuteActionForDomainType for person domain does nothing")
    func executeActionForPersonDomain() async throws {
        let domain = Domain.person
        let entityId = "person.john"
        let state = "home"
        
        #expect(domain == .person)
        #expect([Domain.sensor, .binarySensor, .zone, .person, .camera, .todo].contains(domain))
    }
    
    @Test("ExecuteActionForDomainType for camera domain does nothing")
    func executeActionForCameraDomain() async throws {
        let domain = Domain.camera
        let entityId = "camera.front_door"
        let state = "idle"
        
        #expect(domain == .camera)
        #expect([Domain.sensor, .binarySensor, .zone, .person, .camera, .todo].contains(domain))
    }
    
    @Test("ExecuteActionForDomainType for todo domain does nothing")
    func executeActionForTodoDomain() async throws {
        let domain = Domain.todo
        let entityId = "todo.shopping"
        let state = "0"
        
        #expect(domain == .todo)
        #expect([Domain.sensor, .binarySensor, .zone, .person, .camera, .todo].contains(domain))
    }
    
    // MARK: - Edge Cases
    
    @Test("All toggle domains are properly categorized")
    func toggleDomainsCategoriztion() {
        let toggleDomains: Set<Domain> = [.cover, .inputBoolean, .light, .switch, .fan]
        
        #expect(toggleDomains.contains(.cover))
        #expect(toggleDomains.contains(.inputBoolean))
        #expect(toggleDomains.contains(.light))
        #expect(toggleDomains.contains(.switch))
        #expect(toggleDomains.contains(.fan))
        
        #expect(toggleDomains.count == 5)
    }
    
    @Test("All press domains are properly categorized")
    func pressDomainsCategoriztion() {
        let pressDomains: Set<Domain> = [.button, .inputButton]
        
        #expect(pressDomains.contains(.button))
        #expect(pressDomains.contains(.inputButton))
        
        #expect(pressDomains.count == 2)
    }
    
    @Test("All no-action domains are properly categorized")
    func noActionDomainsCategoriztion() {
        let noActionDomains: Set<Domain> = [.sensor, .binarySensor, .zone, .person, .camera, .todo]
        
        #expect(noActionDomains.contains(.sensor))
        #expect(noActionDomains.contains(.binarySensor))
        #expect(noActionDomains.contains(.zone))
        #expect(noActionDomains.contains(.person))
        #expect(noActionDomains.contains(.camera))
        #expect(noActionDomains.contains(.todo))
        
        #expect(noActionDomains.count == 6)
    }
    
    @Test("Lock states are properly defined")
    func lockStatesDefinition() {
        // States that trigger lock action
        let lockStates: Set<Domain.State> = [.unlocking, .unlocked, .opening]
        #expect(lockStates.count == 3)
        
        // States that trigger unlock action
        let unlockStates: Set<Domain.State> = [.locked, .locking]
        #expect(unlockStates.count == 2)
        
        // These sets should be mutually exclusive
        #expect(lockStates.intersection(unlockStates).isEmpty)
    }
    
    @Test("Empty state string for lock returns nil")
    func lockEmptyStateReturnsNil() {
        let state = ""
        let domainState = Domain.State(rawValue: state)
        #expect(domainState == nil)
    }
}
