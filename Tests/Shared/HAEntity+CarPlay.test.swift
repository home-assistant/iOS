import Foundation
import HAKit
import PromiseKit
@testable import Shared
import Testing
import UIKit

@Suite("HAEntity+CarPlay Tests")
struct HAEntityCarPlayTests {
    // MARK: - Helper Methods
    
    private func createTestEntity(
        entityId: String,
        state: String,
        domain: String? = nil,
        icon: String? = nil,
        deviceClass: String? = nil
    ) throws -> HAEntity {
        var attributes: [String: Any] = [:]
        if let icon {
            attributes["icon"] = icon
        }
        if let deviceClass {
            attributes["device_class"] = deviceClass
        }
        
        return try HAEntity(
            entityId: entityId,
            state: state,
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: .init(value: attributes),
            context: .init(id: "", userId: "", parentId: "")
        )
    }
    
    // MARK: - GetIconWithoutColor Tests
    
    @Test("GetIconWithoutColor for light domain")
    func getIconWithoutColorLight() throws {
        let entity = try createTestEntity(entityId: "light.bedroom", state: "on")
        let icon = entity.getIconWithoutColor()
        #expect(icon == .lightbulbIcon)
    }
    
    @Test("GetIconWithoutColor for switch domain")
    func getIconWithoutColorSwitch() throws {
        let entity = try createTestEntity(entityId: "switch.kitchen", state: "on")
        let icon = entity.getIconWithoutColor()
        // Switch uses state-specific icon
        #expect(icon.name.contains("switch") || icon == .flashIcon)
    }
    
    @Test("GetIconWithoutColor for lock domain - locked")
    func getIconWithoutColorLockLocked() throws {
        let entity = try createTestEntity(entityId: "lock.front_door", state: "locked")
        let icon = entity.getIconWithoutColor()
        #expect(icon == .lockIcon)
    }
    
    @Test("GetIconWithoutColor for lock domain - unlocked")
    func getIconWithoutColorLockUnlocked() throws {
        let entity = try createTestEntity(entityId: "lock.front_door", state: "unlocked")
        let icon = entity.getIconWithoutColor()
        #expect(icon == .lockOpenIcon)
    }
    
    @Test("GetIconWithoutColor for lock domain - jammed")
    func getIconWithoutColorLockJammed() throws {
        let entity = try createTestEntity(entityId: "lock.front_door", state: "jammed")
        let icon = entity.getIconWithoutColor()
        #expect(icon == .lockAlertIcon)
    }
    
    @Test("GetIconWithoutColor for lock domain - locking")
    func getIconWithoutColorLockLocking() throws {
        let entity = try createTestEntity(entityId: "lock.front_door", state: "locking")
        let icon = entity.getIconWithoutColor()
        #expect(icon == .lockClockIcon)
    }
    
    @Test("GetIconWithoutColor for button domain")
    func getIconWithoutColorButton() throws {
        let entity = try createTestEntity(entityId: "button.doorbell", state: "2024-01-01T00:00:00+00:00")
        let icon = entity.getIconWithoutColor()
        #expect(icon == .gestureTapButtonIcon)
    }
    
    @Test("GetIconWithoutColor for button domain with restart device class")
    func getIconWithoutColorButtonRestart() throws {
        let entity = try createTestEntity(
            entityId: "button.restart",
            state: "2024-01-01T00:00:00+00:00",
            deviceClass: "restart"
        )
        let icon = entity.getIconWithoutColor()
        #expect(icon == .restartIcon)
    }
    
    @Test("GetIconWithoutColor for button domain with update device class")
    func getIconWithoutColorButtonUpdate() throws {
        let entity = try createTestEntity(
            entityId: "button.update",
            state: "2024-01-01T00:00:00+00:00",
            deviceClass: "update"
        )
        let icon = entity.getIconWithoutColor()
        #expect(icon == .packageUpIcon)
    }
    
    @Test("GetIconWithoutColor for input_boolean domain - on")
    func getIconWithoutColorInputBooleanOn() throws {
        let entity = try createTestEntity(entityId: "input_boolean.test", state: "on")
        let icon = entity.getIconWithoutColor()
        #expect(icon == .checkCircleOutlineIcon)
    }
    
    @Test("GetIconWithoutColor for input_boolean domain - off")
    func getIconWithoutColorInputBooleanOff() throws {
        let entity = try createTestEntity(entityId: "input_boolean.test", state: "off")
        let icon = entity.getIconWithoutColor()
        #expect(icon == .closeCircleOutlineIcon)
    }
    
    @Test("GetIconWithoutColor for cover domain - garage open")
    func getIconWithoutColorCoverGarageOpen() throws {
        let entity = try createTestEntity(
            entityId: "cover.garage",
            state: "open",
            deviceClass: "garage"
        )
        let icon = entity.getIconWithoutColor()
        #expect(icon == .garageOpenIcon)
    }
    
    @Test("GetIconWithoutColor for cover domain - garage closed")
    func getIconWithoutColorCoverGarageClosed() throws {
        let entity = try createTestEntity(
            entityId: "cover.garage",
            state: "closed",
            deviceClass: "garage"
        )
        let icon = entity.getIconWithoutColor()
        #expect(icon == .garageIcon)
    }
    
    @Test("GetIconWithoutColor for cover domain - garage opening")
    func getIconWithoutColorCoverGarageOpening() throws {
        let entity = try createTestEntity(
            entityId: "cover.garage",
            state: "opening",
            deviceClass: "garage"
        )
        let icon = entity.getIconWithoutColor()
        #expect(icon == .arrowUpBoxIcon)
    }
    
    @Test("GetIconWithoutColor for cover domain - gate")
    func getIconWithoutColorCoverGate() throws {
        let entity = try createTestEntity(
            entityId: "cover.gate",
            state: "closed",
            deviceClass: "gate"
        )
        let icon = entity.getIconWithoutColor()
        #expect(icon == .gateIcon)
    }
    
    @Test("GetIconWithoutColor for cover domain - door")
    func getIconWithoutColorCoverDoor() throws {
        let entity = try createTestEntity(
            entityId: "cover.door",
            state: "open",
            deviceClass: "door"
        )
        let icon = entity.getIconWithoutColor()
        #expect(icon == .doorOpenIcon)
    }
    
    @Test("GetIconWithoutColor for cover domain - shutter")
    func getIconWithoutColorCoverShutter() throws {
        let entity = try createTestEntity(
            entityId: "cover.shutter",
            state: "closed",
            deviceClass: "shutter"
        )
        let icon = entity.getIconWithoutColor()
        #expect(icon == .windowShutterIcon)
    }
    
    @Test("GetIconWithoutColor for cover domain - blind")
    func getIconWithoutColorCoverBlind() throws {
        let entity = try createTestEntity(
            entityId: "cover.blind",
            state: "open",
            deviceClass: "blind"
        )
        let icon = entity.getIconWithoutColor()
        #expect(icon == .blindsOpenIcon)
    }
    
    @Test("GetIconWithoutColor for switch domain - outlet on")
    func getIconWithoutColorSwitchOutletOn() throws {
        let entity = try createTestEntity(
            entityId: "switch.outlet",
            state: "on",
            deviceClass: "outlet"
        )
        let icon = entity.getIconWithoutColor()
        #expect(icon == .powerPlugIcon)
    }
    
    @Test("GetIconWithoutColor for switch domain - outlet off")
    func getIconWithoutColorSwitchOutletOff() throws {
        let entity = try createTestEntity(
            entityId: "switch.outlet",
            state: "off",
            deviceClass: "outlet"
        )
        let icon = entity.getIconWithoutColor()
        #expect(icon == .powerPlugOffIcon)
    }
    
    @Test("GetIconWithoutColor for switch domain - switch on")
    func getIconWithoutColorSwitchOn() throws {
        let entity = try createTestEntity(
            entityId: "switch.test",
            state: "on",
            deviceClass: "switch"
        )
        let icon = entity.getIconWithoutColor()
        #expect(icon == .toggleSwitchIcon)
    }
    
    @Test("GetIconWithoutColor for switch domain - switch off")
    func getIconWithoutColorSwitchOff() throws {
        let entity = try createTestEntity(
            entityId: "switch.test",
            state: "off",
            deviceClass: "switch"
        )
        let icon = entity.getIconWithoutColor()
        #expect(icon == .toggleSwitchOffIcon)
    }
    
    @Test("GetIconWithoutColor with custom icon attribute")
    func getIconWithoutColorCustomIcon() throws {
        let entity = try createTestEntity(
            entityId: "light.test",
            state: "on",
            icon: "mdi:alarm-light"
        )
        let icon = entity.getIconWithoutColor()
        #expect(icon.name == "alarm-light")
    }
    
    @Test("GetIconWithoutColor for scene domain")
    func getIconWithoutColorScene() throws {
        let entity = try createTestEntity(entityId: "scene.movie_night", state: "scening")
        let icon = entity.getIconWithoutColor()
        #expect(icon == .paletteOutlineIcon)
    }
    
    @Test("GetIconWithoutColor for script domain")
    func getIconWithoutColorScript() throws {
        let entity = try createTestEntity(entityId: "script.automation", state: "off")
        let icon = entity.getIconWithoutColor()
        #expect(icon == .scriptTextOutlineIcon)
    }
    
    @Test("GetIconWithoutColor for sensor domain")
    func getIconWithoutColorSensor() throws {
        let entity = try createTestEntity(entityId: "sensor.temperature", state: "21.5")
        let icon = entity.getIconWithoutColor()
        #expect(icon == .eyeIcon)
    }
    
    @Test("GetIconWithoutColor for binary_sensor domain")
    func getIconWithoutColorBinarySensor() throws {
        let entity = try createTestEntity(entityId: "binary_sensor.motion", state: "on")
        let icon = entity.getIconWithoutColor()
        #expect(icon == .eyeIcon)
    }
    
    @Test("GetIconWithoutColor for zone domain")
    func getIconWithoutColorZone() throws {
        let entity = try createTestEntity(entityId: "zone.home", state: "1")
        let icon = entity.getIconWithoutColor()
        #expect(icon == .mapIcon)
    }
    
    @Test("GetIconWithoutColor for person domain")
    func getIconWithoutColorPerson() throws {
        let entity = try createTestEntity(entityId: "person.john", state: "home")
        let icon = entity.getIconWithoutColor()
        #expect(icon == .accountIcon)
    }
    
    @Test("GetIconWithoutColor for camera domain")
    func getIconWithoutColorCamera() throws {
        let entity = try createTestEntity(entityId: "camera.front_door", state: "idle")
        let icon = entity.getIconWithoutColor()
        #expect(icon == .cameraIcon)
    }
    
    @Test("GetIconWithoutColor for fan domain")
    func getIconWithoutColorFan() throws {
        let entity = try createTestEntity(entityId: "fan.bedroom", state: "on")
        let icon = entity.getIconWithoutColor()
        #expect(icon == .fanIcon)
    }
    
    @Test("GetIconWithoutColor for automation domain")
    func getIconWithoutColorAutomation() throws {
        let entity = try createTestEntity(entityId: "automation.test", state: "on")
        let icon = entity.getIconWithoutColor()
        #expect(icon == .homeAutomationIcon)
    }
    
    @Test("GetIconWithoutColor for todo domain")
    func getIconWithoutColorTodo() throws {
        let entity = try createTestEntity(entityId: "todo.shopping", state: "0")
        let icon = entity.getIconWithoutColor()
        #expect(icon == .checkboxMarkedOutlineIcon)
    }
    
    @Test("GetIconWithoutColor for input_button domain")
    func getIconWithoutColorInputButton() throws {
        let entity = try createTestEntity(entityId: "input_button.test", state: "2024-01-01T00:00:00+00:00")
        let icon = entity.getIconWithoutColor()
        #expect(icon == .gestureTapButtonIcon)
    }
    
    @Test("GetIconWithoutColor for unknown domain")
    func getIconWithoutColorUnknownDomain() throws {
        let entity = try createTestEntity(entityId: "unknown.test", state: "unknown")
        let icon = entity.getIconWithoutColor()
        // Should return bookmark icon as fallback
        #expect(icon == .bookmarkIcon)
    }
    
    // MARK: - LocalizedState Tests
    
    @Test("LocalizedState for light domain")
    func localizedStateLight() throws {
        let entity = try createTestEntity(entityId: "light.bedroom", state: "on")
        let localizedState = entity.localizedState
        #expect(!localizedState.isEmpty)
    }
    
    @Test("LocalizedState for lock domain")
    func localizedStateLock() throws {
        let entity = try createTestEntity(entityId: "lock.front_door", state: "locked")
        let localizedState = entity.localizedState
        #expect(!localizedState.isEmpty)
    }
    
    @Test("LocalizedState for cover domain")
    func localizedStateCover() throws {
        let entity = try createTestEntity(entityId: "cover.garage", state: "open")
        let localizedState = entity.localizedState
        #expect(!localizedState.isEmpty)
    }
    
    @Test("LocalizedState for unknown domain")
    func localizedStateUnknownDomain() throws {
        let entity = try createTestEntity(entityId: "unknown.test", state: "custom_state")
        let localizedState = entity.localizedState
        // Should return the state itself when no localization available
        #expect(!localizedState.isEmpty)
    }
    
    @Test("LocalizedState for unavailable state")
    func localizedStateUnavailable() throws {
        let entity = try createTestEntity(entityId: "light.bedroom", state: "unavailable")
        let localizedState = entity.localizedState
        #expect(!localizedState.isEmpty)
    }
    
    // MARK: - Edge Cases
    
    @Test("GetIconWithoutColor handles placeholder entity")
    func getIconWithoutColorPlaceholder() throws {
        let entity = try createTestEntity(
            entityId: "switch.ha_ios_placeholder",
            state: "on",
            deviceClass: "outlet"
        )
        let icon = entity.getIconWithoutColor()
        // Placeholder should use light switch icon
        #expect(icon == .lightSwitchIcon)
    }
    
    @Test("GetIconWithoutColor for cover with unknown device class")
    func getIconWithoutColorCoverUnknownDeviceClass() throws {
        let entity = try createTestEntity(
            entityId: "cover.test",
            state: "open",
            deviceClass: "unknown"
        )
        let icon = entity.getIconWithoutColor()
        // Should use default cover icon for unknown device class
        #expect(icon.name.contains("window") || icon.name.contains("curtain"))
    }
    
    @Test("GetIconWithoutColor for cover with no device class")
    func getIconWithoutColorCoverNoDeviceClass() throws {
        let entity = try createTestEntity(
            entityId: "cover.test",
            state: "open"
        )
        let icon = entity.getIconWithoutColor()
        // Should use default cover icon
        #expect(icon.name.contains("window") || icon.name.contains("curtain"))
    }
    
    @Test("GetIconWithoutColor for switch with no device class")
    func getIconWithoutColorSwitchNoDeviceClass() throws {
        let entity = try createTestEntity(
            entityId: "switch.test",
            state: "on"
        )
        let icon = entity.getIconWithoutColor()
        // Should use flash icon for unknown device class
        #expect(icon == .flashIcon)
    }
    
    @Test("GetIconWithoutColor for input_boolean placeholder")
    func getIconWithoutColorInputBooleanPlaceholder() throws {
        let entity = try createTestEntity(
            entityId: "input_boolean.ha_ios_placeholder",
            state: "on"
        )
        let icon = entity.getIconWithoutColor()
        #expect(icon == .toggleSwitchOutlineIcon)
    }
    
    @Test("GetIconWithoutColor normalizes icon string")
    func getIconWithoutColorNormalizesIcon() throws {
        let entity = try createTestEntity(
            entityId: "light.test",
            state: "on",
            icon: "mdi:lightbulb-outline"
        )
        let icon = entity.getIconWithoutColor()
        // Icon should be normalized (remove mdi: prefix)
        #expect(icon.name == "lightbulb-outline")
    }
}
