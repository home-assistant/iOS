import CoreLocation
import Foundation
import ObjectMapper
import RealmSwift
@testable import Shared
import UIKit
import XCTest

class ActionTests: XCTestCase {
    private var realm: Realm!
    private var server: Server!

    override func setUp() {
        super.setUp()

        let executionIdentifier = UUID().uuidString
        realm = try! Realm(configuration: .init(inMemoryIdentifier: executionIdentifier))
        server = Server.fake(identifier: "test_server")

        Current.realm = { self.realm }
    }

    override func tearDown() {
        super.tearDown()
        Current.realm = Realm.live
    }

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let action = Action()

        XCTAssertFalse(action.ID.isEmpty, "ID should not be empty")
        XCTAssertEqual(action.Name, "", "Name should be empty string by default")
        XCTAssertEqual(action.Text, "", "Text should be empty string by default")
        XCTAssertFalse(action.IconName.isEmpty, "IconName should have a default value")
        XCTAssertFalse(action.BackgroundColor.isEmpty, "BackgroundColor should be set")
        XCTAssertFalse(action.IconColor.isEmpty, "IconColor should be set")
        XCTAssertFalse(action.TextColor.isEmpty, "TextColor should be set")
        XCTAssertEqual(action.Position, 0, "Position should be 0 by default")
        XCTAssertFalse(action.isServerControlled, "isServerControlled should be false by default")
        XCTAssertEqual(action.serverIdentifier, "", "serverIdentifier should be empty by default")
        XCTAssertTrue(action.showInCarPlay, "showInCarPlay should be true by default")
        XCTAssertTrue(action.showInWatch, "showInWatch should be true by default")
        XCTAssertFalse(action.useCustomColors, "useCustomColors should be false by default")
    }

    func testDefaultInitializationSetsAppropriateColors() {
        let action = Action()

        // Verify that colors are valid hex strings
        XCTAssertTrue(action.BackgroundColor.hasPrefix("#") || UIColor(hex: action.BackgroundColor) != nil)
        XCTAssertTrue(action.IconColor.hasPrefix("#") || UIColor(hex: action.IconColor) != nil)
        XCTAssertTrue(action.TextColor.hasPrefix("#") || UIColor(hex: action.TextColor) != nil)

        // Verify that text and icon colors are either black or white (contrasting with background)
        XCTAssertTrue(
            action.TextColor == UIColor.black.hexString() || action.TextColor == UIColor.white.hexString(),
            "TextColor should be either black or white"
        )
        XCTAssertTrue(
            action.IconColor == UIColor.black.hexString() || action.IconColor == UIColor.white.hexString(),
            "IconColor should be either black or white"
        )
    }

    // MARK: - ObjectMapper Tests

    func testMappingFromJSON() throws {
        let json: [String: Any] = [
            "ID": "test_action_id",
            "Name": "Test Action",
            "Text": "Test Text",
            "Position": 10,
            "BackgroundColor": "#FF5733",
            "IconName": "mdi:home",
            "IconColor": "#FFFFFF",
            "TextColor": "#000000",
            "CreatedAt": Date().timeIntervalSince1970,
            "isServerControlled": true,
            "serverIdentifier": "server_1",
            "showInCarPlay": false,
            "showInWatch": false,
            "useCustomColors": true,
        ]

        let action = try Action(JSON: json)

        XCTAssertEqual(action.ID, "test_action_id")
        XCTAssertEqual(action.Name, "Test Action")
        XCTAssertEqual(action.Text, "Test Text")
        XCTAssertEqual(action.Position, 10)
        XCTAssertEqual(action.BackgroundColor, "#FF5733")
        XCTAssertEqual(action.IconName, "mdi:home")
        XCTAssertEqual(action.IconColor, "#FFFFFF")
        XCTAssertEqual(action.TextColor, "#000000")
        XCTAssertTrue(action.isServerControlled)
        XCTAssertEqual(action.serverIdentifier, "server_1")
        XCTAssertFalse(action.showInCarPlay)
        XCTAssertFalse(action.showInWatch)
        XCTAssertTrue(action.useCustomColors)
    }

    func testMappingToJSON() {
        let action = Action()
        action.ID = "test_id"
        action.Name = "Test"
        action.Text = "Test Text"
        action.Position = 5
        action.BackgroundColor = "#123456"
        action.IconName = "mdi:test"
        action.IconColor = "#FFFFFF"
        action.TextColor = "#000000"
        action.isServerControlled = false
        action.serverIdentifier = "server_test"
        action.showInCarPlay = true
        action.showInWatch = true
        action.useCustomColors = false

        let json = action.toJSON()

        XCTAssertEqual(json["ID"] as? String, "test_id")
        XCTAssertEqual(json["Name"] as? String, "Test")
        XCTAssertEqual(json["Text"] as? String, "Test Text")
        XCTAssertEqual(json["Position"] as? Int, 5)
        XCTAssertEqual(json["BackgroundColor"] as? String, "#123456")
        XCTAssertEqual(json["IconName"] as? String, "mdi:test")
        XCTAssertEqual(json["IconColor"] as? String, "#FFFFFF")
        XCTAssertEqual(json["TextColor"] as? String, "#000000")
        XCTAssertEqual(json["isServerControlled"] as? Bool, false)
        XCTAssertEqual(json["serverIdentifier"] as? String, "server_test")
        XCTAssertEqual(json["showInCarPlay"] as? Bool, true)
        XCTAssertEqual(json["showInWatch"] as? Bool, true)
        XCTAssertEqual(json["useCustomColors"] as? Bool, false)
    }

    func testMappingRoundTrip() throws {
        let originalAction = Action()
        originalAction.ID = "roundtrip_id"
        originalAction.Name = "Roundtrip Action"
        originalAction.Text = "Roundtrip Text"
        originalAction.Position = 99
        originalAction.BackgroundColor = "#ABCDEF"
        originalAction.IconName = "mdi:roundtrip"
        originalAction.IconColor = "#111111"
        originalAction.TextColor = "#222222"
        originalAction.isServerControlled = true
        originalAction.serverIdentifier = "roundtrip_server"
        originalAction.showInCarPlay = false
        originalAction.showInWatch = true
        originalAction.useCustomColors = true

        let json = originalAction.toJSON()
        let reconstructedAction = try Action(JSON: json)

        XCTAssertEqual(reconstructedAction.ID, originalAction.ID)
        XCTAssertEqual(reconstructedAction.Name, originalAction.Name)
        XCTAssertEqual(reconstructedAction.Text, originalAction.Text)
        XCTAssertEqual(reconstructedAction.Position, originalAction.Position)
        XCTAssertEqual(reconstructedAction.BackgroundColor, originalAction.BackgroundColor)
        XCTAssertEqual(reconstructedAction.IconName, originalAction.IconName)
        XCTAssertEqual(reconstructedAction.IconColor, originalAction.IconColor)
        XCTAssertEqual(reconstructedAction.TextColor, originalAction.TextColor)
        XCTAssertEqual(reconstructedAction.isServerControlled, originalAction.isServerControlled)
        XCTAssertEqual(reconstructedAction.serverIdentifier, originalAction.serverIdentifier)
        XCTAssertEqual(reconstructedAction.showInCarPlay, originalAction.showInCarPlay)
        XCTAssertEqual(reconstructedAction.showInWatch, originalAction.showInWatch)
        XCTAssertEqual(reconstructedAction.useCustomColors, originalAction.useCustomColors)
    }

    // MARK: - CanConfigure Tests

    func testCanConfigureWhenNotServerControlled() {
        let action = Action()
        action.isServerControlled = false

        XCTAssertTrue(action.canConfigure(\Action.BackgroundColor))
        XCTAssertTrue(action.canConfigure(\Action.TextColor))
        XCTAssertTrue(action.canConfigure(\Action.IconColor))
        XCTAssertTrue(action.canConfigure(\Action.IconName))
        XCTAssertTrue(action.canConfigure(\Action.Name))
        XCTAssertTrue(action.canConfigure(\Action.Text))
        XCTAssertTrue(action.canConfigure(\Action.serverIdentifier))
        XCTAssertTrue(action.canConfigure(\Action.showInCarPlay))
        XCTAssertTrue(action.canConfigure(\Action.showInWatch))
        XCTAssertTrue(action.canConfigure(\Action.useCustomColors))
        XCTAssertTrue(action.canConfigure(\Action.Position))
    }

    func testCannotConfigureWhenServerControlled() {
        let action = Action()
        action.isServerControlled = true

        XCTAssertFalse(action.canConfigure(\Action.BackgroundColor))
        XCTAssertFalse(action.canConfigure(\Action.TextColor))
        XCTAssertFalse(action.canConfigure(\Action.IconColor))
        XCTAssertFalse(action.canConfigure(\Action.IconName))
        XCTAssertFalse(action.canConfigure(\Action.Name))
        XCTAssertFalse(action.canConfigure(\Action.Text))
        XCTAssertFalse(action.canConfigure(\Action.serverIdentifier))
        XCTAssertFalse(action.canConfigure(\Action.showInCarPlay))
        XCTAssertFalse(action.canConfigure(\Action.showInWatch))
        XCTAssertFalse(action.canConfigure(\Action.useCustomColors))
        XCTAssertTrue(action.canConfigure(\Action.Position))
    }

    func testCanConfigureWithScene() throws {
        let scene = RLMScene()
        scene.identifier = "scene.test"
        scene.serverIdentifier = "server_1"
        scene.backgroundColor = "#FF0000"
        scene.textColor = "#00FF00"
        scene.iconColor = "#0000FF"

        try realm.write {
            realm.add(scene)
        }

        let action = Action()
        action.ID = "scene.test"
        action.isServerControlled = false

        try realm.write {
            action.Scene = scene
            realm.add(action)
        }

        // When scene has colors set, cannot configure those colors
        XCTAssertFalse(action.canConfigure(\Action.BackgroundColor))
        XCTAssertFalse(action.canConfigure(\Action.TextColor))
        XCTAssertFalse(action.canConfigure(\Action.IconColor))

        // When scene exists, cannot configure these
        XCTAssertFalse(action.canConfigure(\Action.IconName))
        XCTAssertFalse(action.canConfigure(\Action.Name))
        XCTAssertFalse(action.canConfigure(\Action.Text))
        XCTAssertFalse(action.canConfigure(\Action.serverIdentifier))
        XCTAssertFalse(action.canConfigure(\Action.showInCarPlay))
        XCTAssertFalse(action.canConfigure(\Action.showInWatch))
        XCTAssertFalse(action.canConfigure(\Action.useCustomColors))
    }

    func testCanConfigureWithSceneWithoutColors() throws {
        let scene = RLMScene()
        scene.identifier = "scene.test"
        scene.serverIdentifier = "server_1"
        scene.backgroundColor = nil
        scene.textColor = nil
        scene.iconColor = nil

        try realm.write {
            realm.add(scene)
        }

        let action = Action()
        action.ID = "scene.test"
        action.isServerControlled = false

        try realm.write {
            action.Scene = scene
            realm.add(action)
        }

        // When scene doesn't have colors, can configure them
        XCTAssertTrue(action.canConfigure(\Action.BackgroundColor))
        XCTAssertTrue(action.canConfigure(\Action.TextColor))
        XCTAssertTrue(action.canConfigure(\Action.IconColor))

        // When scene exists, still cannot configure these
        XCTAssertFalse(action.canConfigure(\Action.IconName))
        XCTAssertFalse(action.canConfigure(\Action.Name))
        XCTAssertFalse(action.canConfigure(\Action.Text))
    }

    // MARK: - TriggerType Tests

    func testTriggerTypeForEvent() {
        let action = Action()
        action.ID = "custom_action"

        XCTAssertEqual(action.triggerType, .event)
    }

    func testTriggerTypeForScene() {
        let action = Action()
        action.ID = "scene.living_room"

        XCTAssertEqual(action.triggerType, .scene)
    }

    func testTriggerTypeForSceneWithDifferentFormat() {
        let action = Action()
        action.ID = "scene.bedroom_lights"

        XCTAssertEqual(action.triggerType, .scene)
    }

    // MARK: - Update with MobileAppConfigAction Tests

    func testUpdateWithMobileAppConfigAction() throws {
        let configAction = try MobileAppConfigAction(JSON: [
            "name": "test_action",
            "background_color": "#FF0000",
            "label": ["text": "Test Label", "color": "#00FF00"],
            "icon": ["icon": "mdi:test", "color": "#0000FF"],
            "show_in_carplay": true,
            "show_in_watch": false,
            "use_custom_colors": true,
        ])

        let action = Action()

        try realm.write {
            let result = action.update(with: configAction, server: server, using: realm)
            XCTAssertTrue(result)
        }

        XCTAssertEqual(action.ID, "test_action")
        XCTAssertEqual(action.Name, "test_action")
        XCTAssertEqual(action.BackgroundColor, "#FF0000")
        XCTAssertEqual(action.Text, "Test Label")
        XCTAssertEqual(action.TextColor, "#00FF00")
        XCTAssertEqual(action.IconName, "mdi:test")
        XCTAssertEqual(action.IconColor, "#0000FF")
        XCTAssertTrue(action.isServerControlled)
        XCTAssertEqual(action.serverIdentifier, server.identifier.rawValue)
        XCTAssertTrue(action.showInCarPlay)
        XCTAssertFalse(action.showInWatch)
        XCTAssertTrue(action.useCustomColors)
    }

    func testUpdateWithMobileAppConfigActionMinimalFields() throws {
        let configAction = try MobileAppConfigAction(JSON: [
            "name": "minimal_action",
        ])

        let action = Action()

        try realm.write {
            let result = action.update(with: configAction, server: server, using: realm)
            XCTAssertTrue(result)
        }

        XCTAssertEqual(action.ID, "minimal_action")
        XCTAssertEqual(action.Name, "minimal_action")
        XCTAssertEqual(action.Text, "Minimal Action") // Should be formatted name
        XCTAssertFalse(action.IconName.isEmpty) // Should have generated icon
        XCTAssertTrue(action.isServerControlled)
    }

    func testUpdateWithMobileAppConfigActionPreservesIDAndName() throws {
        let configAction = try MobileAppConfigAction(JSON: [
            "name": "existing_action",
            "label": ["text": "New Text"],
        ])

        let action = Action()
        action.ID = "existing_action"
        action.Name = "existing_action"

        try realm.write {
            realm.add(action)
        }

        try realm.write {
            let result = action.update(with: configAction, server: server, using: realm)
            XCTAssertTrue(result)
        }

        XCTAssertEqual(action.ID, "existing_action")
        XCTAssertEqual(action.Name, "existing_action")
        XCTAssertEqual(action.Text, "New Text")
    }

    // MARK: - DidUpdate Tests

    func testDidUpdateSetsPositions() throws {
        let action1 = Action()
        action1.ID = "action1"
        let action2 = Action()
        action2.ID = "action2"
        let action3 = Action()
        action3.ID = "action3"

        let actions = [action1, action2, action3]

        try realm.write {
            Action.didUpdate(objects: actions, server: server, realm: realm)
        }

        XCTAssertEqual(action1.Position, Action.PositionOffset.synced.rawValue + server.info.sortOrder)
        XCTAssertEqual(action2.Position, Action.PositionOffset.synced.rawValue + server.info.sortOrder + 1)
        XCTAssertEqual(action3.Position, Action.PositionOffset.synced.rawValue + server.info.sortOrder + 2)
    }

    // MARK: - UIColor Random Background Tests

    func testRandomBackgroundColorProperties() {
        for _ in 0 ..< 100 {
            let color = UIColor.randomBackgroundColor()
            var hue: CGFloat = 0
            var saturation: CGFloat = 0
            var brightness: CGFloat = 0
            var alpha: CGFloat = 0

            color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

            XCTAssertGreaterThanOrEqual(saturation, 0.5, "Saturation should be >= 0.5")
            XCTAssertLessThanOrEqual(saturation, 1.0, "Saturation should be <= 1.0")
            XCTAssertGreaterThanOrEqual(brightness, 0.25, "Brightness should be >= 0.25")
            XCTAssertLessThanOrEqual(brightness, 0.75, "Brightness should be <= 0.75")
            XCTAssertEqual(alpha, 1.0, "Alpha should be 1.0")
        }
    }

    // MARK: - Edge Cases

    func testEmptyJSONMapping() {
        let json: [String: Any] = [:]
        XCTAssertThrowsError(try Action(JSON: json))
    }
}
