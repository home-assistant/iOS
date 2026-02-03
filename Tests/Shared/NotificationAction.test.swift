import Foundation
import RealmSwift
@testable import Shared
import UserNotifications
import XCTest

class NotificationActionTests: XCTestCase {
    private var realm: Realm!
    private var testQueue: DispatchQueue!

    override func setUpWithError() throws {
        try super.setUpWithError()

        testQueue = DispatchQueue(label: #file)
        let executionIdentifier = UUID().uuidString
        try testQueue.sync {
            realm = try Realm(configuration: .init(inMemoryIdentifier: executionIdentifier), queue: testQueue)
        }
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let action = NotificationAction()

        XCTAssertFalse(action.uuid.isEmpty)
        XCTAssertEqual(action.Identifier, "")
        XCTAssertEqual(action.Title, "")
        XCTAssertFalse(action.TextInput)
        XCTAssertFalse(action.isServerControlled)
        XCTAssertNil(action.icon)
        XCTAssertFalse(action.Foreground)
        XCTAssertFalse(action.Destructive)
        XCTAssertFalse(action.AuthenticationRequired)
    }

    func testUUIDIsUnique() {
        let action1 = NotificationAction()
        let action2 = NotificationAction()

        XCTAssertNotEqual(action1.uuid, action2.uuid)
    }

    // MARK: - Convenience Initializer Tests

    func testInitWithMobileAppConfigPushCategoryAction() {
        let pushAction = createMockPushAction(
            title: "Reply",
            identifier: "reply_action",
            authenticationRequired: true,
            behavior: "textinput",
            activationMode: "foreground",
            destructive: false,
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Type here",
            url: nil,
            icon: "sfsymbols:message"
        )

        let action = NotificationAction(action: pushAction)

        XCTAssertTrue(action.isServerControlled)
        XCTAssertEqual(action.Title, "Reply")
        XCTAssertEqual(action.Identifier, "reply_action")
        XCTAssertTrue(action.AuthenticationRequired)
        XCTAssertTrue(action.Foreground)
        XCTAssertFalse(action.Destructive)
        XCTAssertTrue(action.TextInput)
        XCTAssertEqual(action.icon, "sfsymbols:message")
        XCTAssertEqual(action.TextInputButtonTitle, "Send")
        XCTAssertEqual(action.TextInputPlaceholder, "Type here")
    }

    func testInitWithMobileAppConfigActionBackgroundMode() {
        let pushAction = createMockPushAction(
            title: "Dismiss",
            identifier: "dismiss_action",
            authenticationRequired: false,
            behavior: "default",
            activationMode: "background",
            destructive: true,
            textInputButtonTitle: nil,
            textInputPlaceholder: nil,
            url: nil,
            icon: nil
        )

        let action = NotificationAction(action: pushAction)

        XCTAssertEqual(action.Title, "Dismiss")
        XCTAssertFalse(action.Foreground)
        XCTAssertTrue(action.Destructive)
        XCTAssertFalse(action.TextInput)
    }

    func testInitWithMobileAppConfigActionForegroundMode() {
        let pushAction = createMockPushAction(
            title: "Open",
            identifier: "open_action",
            authenticationRequired: false,
            behavior: "default",
            activationMode: "foreground",
            destructive: false,
            textInputButtonTitle: nil,
            textInputPlaceholder: nil,
            url: nil,
            icon: nil
        )

        let action = NotificationAction(action: pushAction)

        XCTAssertTrue(action.Foreground)
    }

    func testInitWithMobileAppConfigActionTextInput() {
        let pushAction = createMockPushAction(
            title: "Reply",
            identifier: "reply",
            authenticationRequired: false,
            behavior: "textinput",
            activationMode: "background",
            destructive: false,
            textInputButtonTitle: nil,
            textInputPlaceholder: nil,
            url: nil,
            icon: nil
        )

        let action = NotificationAction(action: pushAction)

        XCTAssertTrue(action.TextInput)
    }

    func testInitWithMobileAppConfigActionDefaultTextInputValues() {
        let pushAction = createMockPushAction(
            title: "Reply",
            identifier: "reply",
            authenticationRequired: false,
            behavior: "textinput",
            activationMode: "background",
            destructive: false,
            textInputButtonTitle: nil,
            textInputPlaceholder: nil,
            url: nil,
            icon: nil
        )

        let action = NotificationAction(action: pushAction)

        XCTAssertEqual(
            action.TextInputButtonTitle,
            L10n.NotificationsConfigurator.Action.Rows.TextInputButtonTitle.title
        )
        XCTAssertEqual(
            action.TextInputPlaceholder,
            L10n.NotificationsConfigurator.Action.Rows.TextInputPlaceholder.title
        )
    }

    // MARK: - Options Tests

    func testOptionsWithAllEnabled() {
        let action = NotificationAction()
        action.AuthenticationRequired = true
        action.Destructive = true
        action.Foreground = true

        let options = action.options
        XCTAssertTrue(options.contains(.authenticationRequired))
        XCTAssertTrue(options.contains(.destructive))
        XCTAssertTrue(options.contains(.foreground))
    }

    // MARK: - Action Property Tests

    func testActionPropertyWithTextInput() {
        let action = NotificationAction()
        action.Identifier = "reply_action"
        action.Title = "Reply"
        action.TextInput = true
        action.TextInputButtonTitle = "Send"
        action.TextInputPlaceholder = "Type here"

        let unAction = action.action
        XCTAssertTrue(unAction is UNTextInputNotificationAction)

        if let textInputAction = unAction as? UNTextInputNotificationAction {
            XCTAssertEqual(textInputAction.textInputButtonTitle, "Send")
            XCTAssertEqual(textInputAction.textInputPlaceholder, "Type here")
        } else {
            XCTFail("Action should be UNTextInputNotificationAction")
        }
    }

    func testActionPropertyWithOptions() {
        let action = NotificationAction()
        action.Identifier = "delete_action"
        action.Title = "Delete"
        action.Destructive = true
        action.Foreground = true

        let unAction = action.action
        XCTAssertTrue(unAction.options.contains(.destructive))
        XCTAssertTrue(unAction.options.contains(.foreground))
    }

    func testActionPropertyWithSFSymbolIcon() {
        let action = NotificationAction()
        action.Identifier = "star_action"
        action.Title = "Star"
        action.icon = "sfsymbols:star"

        let unAction = action.action
        XCTAssertNotNil(unAction.icon)
    }

    // MARK: - Example Trigger Tests

    func testExampleTriggerWithoutTextInput() {
        let api = FakeHomeAssistantAPI(server: .fake())

        let trigger = NotificationAction.exampleTrigger(
            api: api,
            identifier: "test_action",
            category: "test_category",
            textInput: false
        )

        XCTAssertTrue(trigger.contains("platform: event"))
        XCTAssertTrue(trigger.contains("event_type:"))
        XCTAssertTrue(trigger.contains("event_data:"))
        XCTAssertFalse(trigger.contains("# text you input"))
    }

    func testExampleTriggerWithTextInput() {
        let api = FakeHomeAssistantAPI(server: .fake())

        let trigger = NotificationAction.exampleTrigger(
            api: api,
            identifier: "reply_action",
            category: "message_category",
            textInput: true
        )

        XCTAssertTrue(trigger.contains("platform: event"))
        XCTAssertTrue(trigger.contains("event_type:"))
        XCTAssertTrue(trigger.contains("event_data:"))
        XCTAssertTrue(trigger.contains("# text you input"))
    }

    func testExampleTriggerWithoutCategory() {
        let api = FakeHomeAssistantAPI(server: .fake())

        let trigger = NotificationAction.exampleTrigger(
            api: api,
            identifier: "test_action",
            category: nil,
            textInput: false
        )

        XCTAssertTrue(trigger.contains("platform: event"))
    }

    // MARK: - Persistence Tests

    func testPersistenceWithRealm() throws {
        try testQueue.sync {
            try realm.write {
                let action = NotificationAction()
                action.Identifier = "persisted_action"
                action.Title = "Persisted Action"
                realm.add(action)
            }

            let retrieved = realm.object(ofType: NotificationAction.self, forPrimaryKey: action.uuid)
            XCTAssertNotNil(retrieved)
            XCTAssertEqual(retrieved?.Title, "Persisted Action")
        }

        func action() -> NotificationAction {
            let action = NotificationAction()
            try! realm.write {
                realm.add(action)
            }
            return action
        }
    }

    func testPersistenceWithCategory() throws {
        try testQueue.sync {
            try realm.write {
                let category = NotificationCategory()
                category.Identifier = "test_category"
                category.Name = "Test Category"

                let action = NotificationAction()
                action.Identifier = "action_in_category"
                action.Title = "Action"

                category.Actions.append(action)
                realm.add(category)
            }

            let retrievedCategory = realm.object(
                ofType: NotificationCategory.self,
                forPrimaryKey: "test_category"
            )
            XCTAssertNotNil(retrievedCategory)
            XCTAssertEqual(retrievedCategory?.Actions.count, 1)

            let retrievedAction = retrievedCategory?.Actions.first
            XCTAssertNotNil(retrievedAction)
            XCTAssertEqual(retrievedAction?.Identifier, "action_in_category")
            XCTAssertEqual(retrievedAction?.categories.count, 1)
        }
    }

    // MARK: - Edge Cases Tests

    func testTextInputWithEmptyButtonTitle() {
        let action = NotificationAction()
        action.TextInput = true
        action.TextInputButtonTitle = ""
        action.TextInputPlaceholder = ""

        let unAction = action.action
        XCTAssertTrue(unAction is UNTextInputNotificationAction)

        if let textInputAction = unAction as? UNTextInputNotificationAction {
            XCTAssertEqual(textInputAction.textInputButtonTitle, "")
            XCTAssertEqual(textInputAction.textInputPlaceholder, "")
        }
    }

    func testCaseInsensitiveActivationMode() {
        let pushAction1 = createMockPushAction(
            title: "Test",
            identifier: "test1",
            authenticationRequired: false,
            behavior: "default",
            activationMode: "FOREGROUND",
            destructive: false,
            textInputButtonTitle: nil,
            textInputPlaceholder: nil,
            url: nil,
            icon: nil
        )

        let action1 = NotificationAction(action: pushAction1)
        XCTAssertTrue(action1.Foreground)

        let pushAction2 = createMockPushAction(
            title: "Test",
            identifier: "test2",
            authenticationRequired: false,
            behavior: "default",
            activationMode: "Background",
            destructive: false,
            textInputButtonTitle: nil,
            textInputPlaceholder: nil,
            url: nil,
            icon: nil
        )

        let action2 = NotificationAction(action: pushAction2)
        XCTAssertFalse(action2.Foreground)
    }

    func testCaseInsensitiveBehavior() {
        let pushAction1 = createMockPushAction(
            title: "Test",
            identifier: "test1",
            authenticationRequired: false,
            behavior: "TEXTINPUT",
            activationMode: "background",
            destructive: false,
            textInputButtonTitle: nil,
            textInputPlaceholder: nil,
            url: nil,
            icon: nil
        )

        let action1 = NotificationAction(action: pushAction1)
        XCTAssertTrue(action1.TextInput)

        let pushAction2 = createMockPushAction(
            title: "Test",
            identifier: "test2",
            authenticationRequired: false,
            behavior: "TextInput",
            activationMode: "background",
            destructive: false,
            textInputButtonTitle: nil,
            textInputPlaceholder: nil,
            url: nil,
            icon: nil
        )

        let action2 = NotificationAction(action: pushAction2)
        XCTAssertTrue(action2.TextInput)
    }

    func testMultipleActionsWithSameIdentifier() throws {
        try testQueue.sync {
            try realm.write {
                let action1 = NotificationAction()
                action1.Identifier = "same_identifier"
                action1.Title = "Action 1"

                let action2 = NotificationAction()
                action2.Identifier = "same_identifier"
                action2.Title = "Action 2"

                realm.add(action1)
                realm.add(action2)

                XCTAssertNotEqual(action1.uuid, action2.uuid)
            }
        }
    }
}

// MARK: - Helper Functions

private func createMockPushAction(
    title: String,
    identifier: String,
    authenticationRequired: Bool,
    behavior: String,
    activationMode: String,
    destructive: Bool,
    textInputButtonTitle: String?,
    textInputPlaceholder: String?,
    url: String?,
    icon: String?
) -> MobileAppConfigPushCategory.Action {
    MobileAppConfigPushCategory.Action(
        title: title,
        identifier: identifier,
        authenticationRequired: authenticationRequired,
        behavior: behavior,
        activationMode: activationMode,
        destructive: destructive,
        textInputButtonTitle: textInputButtonTitle,
        textInputPlaceholder: textInputPlaceholder,
        url: url,
        icon: icon
    )
}

// MARK: - Helper Extensions

private extension MobileAppConfigPushCategory.Action {
    init(
        title: String,
        identifier: String,
        authenticationRequired: Bool,
        behavior: String,
        activationMode: String,
        destructive: Bool,
        textInputButtonTitle: String?,
        textInputPlaceholder: String?,
        url: String?,
        icon: String?
    ) {
        self = createMockPushAction(
            title: title,
            identifier: identifier,
            authenticationRequired: authenticationRequired,
            behavior: behavior,
            activationMode: activationMode,
            destructive: destructive,
            textInputButtonTitle: textInputButtonTitle,
            textInputPlaceholder: textInputPlaceholder,
            url: url,
            icon: icon
        )
    }
}
