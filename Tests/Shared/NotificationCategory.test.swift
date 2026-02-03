import Foundation
import RealmSwift
@testable import Shared
import UserNotifications
import XCTest

class NotificationCategoryTests: XCTestCase {
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
        Current.realm = Realm.live
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let category = NotificationCategory()

        XCTAssertFalse(category.isServerControlled)
        XCTAssertEqual(category.serverIdentifier, "")
        XCTAssertEqual(category.Name, "")
        XCTAssertEqual(category.Identifier, "")
        XCTAssertNil(category.HiddenPreviewsBodyPlaceholder)
        XCTAssertNil(category.CategorySummaryFormat)
        XCTAssertTrue(category.SendDismissActions)
        XCTAssertFalse(category.HiddenPreviewsShowTitle)
        XCTAssertFalse(category.HiddenPreviewsShowSubtitle)
        XCTAssertEqual(category.Actions.count, 0)
    }

    // MARK: - Options Tests

    #if os(iOS)
    func testOptionsWithAllEnabled() {
        let category = NotificationCategory()
        category.SendDismissActions = true
        category.HiddenPreviewsShowTitle = true
        category.HiddenPreviewsShowSubtitle = true

        let options = category.options
        XCTAssertTrue(options.contains(.customDismissAction))
        XCTAssertTrue(options.contains(.hiddenPreviewsShowTitle))
        XCTAssertTrue(options.contains(.hiddenPreviewsShowSubtitle))
    }
    #endif

    // MARK: - Categories Tests

    #if os(iOS)
    func testCategoriesProperty() {
        let category = NotificationCategory()
        category.Identifier = "test_category"
        category.Name = "Test Category"
        category.HiddenPreviewsBodyPlaceholder = "Hidden"
        category.CategorySummaryFormat = "%u messages"

        let categories = category.categories
        XCTAssertEqual(categories.count, 1)

        let unCategory = categories.first
        XCTAssertNotNil(unCategory)
        XCTAssertEqual(unCategory?.identifier, "TEST_CATEGORY")
    }

    func testCategoriesWithActions() throws {
        try testQueue.sync {
            try realm.write {
                let category = NotificationCategory()
                category.Identifier = "test_category"
                category.Name = "Test Category"

                let action1 = NotificationAction()
                action1.Identifier = "action1"
                action1.Title = "Action 1"

                let action2 = NotificationAction()
                action2.Identifier = "action2"
                action2.Title = "Action 2"

                category.Actions.append(objectsIn: [action1, action2])
                realm.add(category)

                let categories = category.categories
                XCTAssertEqual(categories.count, 1)
                XCTAssertEqual(categories.first?.actions.count, 2)
            }
        }
    }
    #endif

    // MARK: - Example Service Call Tests

    func testExampleServiceCallWithActions() throws {
        try testQueue.sync {
            try realm.write {
                let category = NotificationCategory()
                category.Identifier = "test_category"

                let action1 = NotificationAction()
                action1.Identifier = "action1"
                action1.Title = "Action 1"

                category.Actions.append(action1)
                realm.add(category)

                let serviceCall = category.exampleServiceCall
                XCTAssertTrue(serviceCall.contains("category: TEST_CATEGORY"))
                XCTAssertTrue(serviceCall.contains("\"action1\": \"http://example.com/url\""))
            }
        }
    }

    func testExampleServiceCallContainsFallbackActionIdentifier() {
        let category = NotificationCategory()
        category.Identifier = "test"

        let serviceCall = category.exampleServiceCall
        XCTAssertTrue(serviceCall.contains("\"_\": \"http://example.com/fallback\""))
    }

    // MARK: - Update Tests

    func testUpdateWithMobileAppConfigPushCategory() throws {
        let servers = FakeServerManager(initial: 1)
        let server = servers.server(forServerIdentifier: servers.all.first!.identifier)!

        try testQueue.sync {
            try realm.write {
                let category = NotificationCategory()

                let action = MobileAppConfigPushCategory.Action(
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

                let pushCategory = MobileAppConfigPushCategory(
                    name: "Test Category",
                    identifier: "test_category",
                    actions: [action]
                )

                let updated = category.update(with: pushCategory, server: server, using: realm)

                XCTAssertTrue(updated)
                XCTAssertTrue(category.isServerControlled)
                XCTAssertEqual(category.serverIdentifier, server.identifier.rawValue)
                XCTAssertEqual(category.Name, "Test Category")
                XCTAssertEqual(category.Identifier, "TEST_CATEGORY")
                XCTAssertEqual(category.Actions.count, 1)

                let updatedAction = category.Actions.first
                XCTAssertNotNil(updatedAction)
                XCTAssertEqual(updatedAction?.Title, "Reply")
                XCTAssertEqual(updatedAction?.Identifier, "reply_action")
                XCTAssertTrue(updatedAction?.AuthenticationRequired ?? false)
                XCTAssertTrue(updatedAction?.TextInput ?? false)
                XCTAssertTrue(updatedAction?.Foreground ?? false)
            }
        }
    }

    func testUpdatePreservesIdentifier() throws {
        let servers = FakeServerManager(initial: 1)
        let server = servers.server(forServerIdentifier: servers.all.first!.identifier)!

        try testQueue.sync {
            try realm.write {
                let category = NotificationCategory()
                category.Identifier = "EXISTING_CATEGORY"
                realm.add(category)

                let pushCategory = MobileAppConfigPushCategory(
                    name: "Updated Category",
                    identifier: "existing_category",
                    actions: []
                )

                let updated = category.update(with: pushCategory, server: server, using: realm)

                XCTAssertTrue(updated)
                XCTAssertEqual(category.Identifier, "EXISTING_CATEGORY")
            }
        }
    }

    func testUpdateReplacesActions() throws {
        let servers = FakeServerManager(initial: 1)
        let server = servers.server(forServerIdentifier: servers.all.first!.identifier)!

        try testQueue.sync {
            try realm.write {
                let category = NotificationCategory()
                category.Identifier = "TEST_CATEGORY"

                let oldAction = NotificationAction()
                oldAction.Identifier = "old_action"
                oldAction.Title = "Old Action"
                category.Actions.append(oldAction)
                realm.add(category)

                XCTAssertEqual(category.Actions.count, 1)

                let newAction = MobileAppConfigPushCategory.Action(
                    title: "New Action",
                    identifier: "new_action",
                    authenticationRequired: false,
                    behavior: "default",
                    activationMode: "background",
                    destructive: false,
                    textInputButtonTitle: nil,
                    textInputPlaceholder: nil,
                    url: nil,
                    icon: nil
                )

                let pushCategory = MobileAppConfigPushCategory(
                    name: "Test Category",
                    identifier: "test_category",
                    actions: [newAction]
                )

                let updated = category.update(with: pushCategory, server: server, using: realm)

                XCTAssertTrue(updated)
                XCTAssertEqual(category.Actions.count, 1)
                XCTAssertEqual(category.Actions.first?.Identifier, "new_action")
                XCTAssertEqual(category.Actions.first?.Title, "New Action")
            }
        }
    }

    // MARK: - Persistence Tests

    func testPersistenceWithRealm() throws {
        try testQueue.sync {
            try realm.write {
                let category = NotificationCategory()
                category.Identifier = "persisted_category"
                category.Name = "Persisted Category"
                category.isServerControlled = true
                category.serverIdentifier = "server_1"
                realm.add(category)
            }

            let retrieved = realm.object(ofType: NotificationCategory.self, forPrimaryKey: "persisted_category")
            XCTAssertNotNil(retrieved)
            XCTAssertEqual(retrieved?.Name, "Persisted Category")
            XCTAssertTrue(retrieved?.isServerControlled ?? false)
            XCTAssertEqual(retrieved?.serverIdentifier, "server_1")
        }
    }

    func testPersistenceWithActions() throws {
        try testQueue.sync {
            try realm.write {
                let category = NotificationCategory()
                category.Identifier = "category_with_actions"
                category.Name = "Category With Actions"

                let action = NotificationAction()
                action.Identifier = "action_1"
                action.Title = "Action 1"
                category.Actions.append(action)

                realm.add(category)
            }

            let retrieved = realm.object(ofType: NotificationCategory.self, forPrimaryKey: "category_with_actions")
            XCTAssertNotNil(retrieved)
            XCTAssertEqual(retrieved?.Actions.count, 1)
            XCTAssertEqual(retrieved?.Actions.first?.Title, "Action 1")
        }
    }

    // MARK: - Edge Cases Tests

    func testCaseInsensitiveIdentifier() {
        let category = NotificationCategory()
        category.Identifier = "lowercase"

        #if os(iOS)
        let categories = category.categories
        XCTAssertEqual(categories.first?.identifier, "LOWERCASE")
        #endif

        let serviceCall = category.exampleServiceCall
        XCTAssertTrue(serviceCall.contains("category: LOWERCASE"))
    }
}

// MARK: - Helper Extensions

private extension MobileAppConfigPushCategory {
    init(name: String, identifier: String, actions: [Action]) {
        self.name = name
        self.identifier = identifier
        self.actions = actions
    }
}

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
        self.title = title
        self.identifier = identifier
        self.authenticationRequired = authenticationRequired
        self.behavior = behavior
        self.activationMode = activationMode
        self.destructive = destructive
        self.textInputButtonTitle = textInputButtonTitle
        self.textInputPlaceholder = textInputPlaceholder
        self.url = url
        self.icon = icon
    }
}
