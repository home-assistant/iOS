@testable import HomeAssistant
import RealmSwift
@testable import Shared
import Testing

@Suite(.serialized)
struct MagicItemAddViewModelTests {
    private var realm: Realm!
    private var sut: MagicItemAddViewModel!
    private let originalRealm: () -> Realm

    init() async throws {
        // Store original realm configuration to restore later
        self.originalRealm = Current.realm

        // Setup in-memory Realm for testing
        var configuration = Realm.Configuration.defaultConfiguration
        configuration.inMemoryIdentifier = UUID().uuidString
        self.realm = try Realm(configuration: configuration)

        // Setup Current.realm to use our test realm
        let testRealm = realm!
        Current.realm = { testRealm }

        self.sut = MagicItemAddViewModel()
    }

    deinit {
        // Restore original realm configuration to avoid side effects on other tests
        Current.realm = originalRealm
    }

    // MARK: - Initial State Tests

    @Test("Initial state has default values")
    func testInitialState() async throws {
        #expect(sut.selectedItemType == .scripts)
        #expect(sut.actions.isEmpty)
        #expect(sut.searchText == "")
        #expect(sut.selectedServerId == nil)
    }

    // MARK: - Load Actions Tests

    @MainActor
    @Test("Load content filters out actions with scenes")
    func testLoadContentFiltersActionsWithScenes() async throws {
        // Create a scene
        let scene = RLMScene()
        scene.identifier = "scene-1"

        // Create actions - one with scene, one without
        let actionWithScene = Action()
        actionWithScene.ID = "action-1"
        actionWithScene.Name = "Action With Scene"
        actionWithScene.Text = "Action 1"
        actionWithScene.Position = 0
        actionWithScene.Scene = scene

        let actionWithoutScene = Action()
        actionWithoutScene.ID = "action-2"
        actionWithoutScene.Name = "Action Without Scene"
        actionWithoutScene.Text = "Action 2"
        actionWithoutScene.Position = 1

        try realm.write {
            realm.add(scene)
            realm.add(actionWithScene)
            realm.add(actionWithoutScene)
        }

        await sut.loadContent()

        #expect(sut.actions.count == 1)
        #expect(sut.actions.first?.ID == "action-2")
    }

    @MainActor
    @Test("Load content sorts actions by position")
    func testLoadContentSortsActionsByPosition() async throws {
        let action1 = Action()
        action1.ID = "action-1"
        action1.Name = "Action 1"
        action1.Text = "First"
        action1.Position = 2

        let action2 = Action()
        action2.ID = "action-2"
        action2.Name = "Action 2"
        action2.Text = "Second"
        action2.Position = 0

        let action3 = Action()
        action3.ID = "action-3"
        action3.Name = "Action 3"
        action3.Text = "Third"
        action3.Position = 1

        try realm.write {
            realm.add(action1)
            realm.add(action2)
            realm.add(action3)
        }

        await sut.loadContent()

        #expect(sut.actions.count == 3)
        #expect(sut.actions[0].Position == 0)
        #expect(sut.actions[1].Position == 1)
        #expect(sut.actions[2].Position == 2)
        #expect(sut.actions[0].ID == "action-2")
        #expect(sut.actions[1].ID == "action-3")
        #expect(sut.actions[2].ID == "action-1")
    }

    @MainActor
    @Test("Load content multiple times updates actions")
    func testLoadContentMultipleTimesUpdatesActions() async throws {
        // First load - empty
        await sut.loadContent()
        #expect(sut.actions.isEmpty)

        // Add an action
        let action1 = Action()
        action1.ID = "action-1"
        action1.Name = "Action 1"
        action1.Text = "First"
        action1.Position = 0

        try realm.write {
            realm.add(action1)
        }

        // Second load - should have 1 action
        await sut.loadContent()
        #expect(sut.actions.count == 1)

        // Add another action
        let action2 = Action()
        action2.ID = "action-2"
        action2.Name = "Action 2"
        action2.Text = "Second"
        action2.Position = 1

        try realm.write {
            realm.add(action2)
        }

        // Third load - should have 2 actions
        await sut.loadContent()
        #expect(sut.actions.count == 2)
    }

    @MainActor
    @Test("Load content handles actions with same position")
    func testLoadContentHandlesActionsWithSamePosition() async throws {
        let action1 = Action()
        action1.ID = "action-1"
        action1.Name = "Action 1"
        action1.Text = "First"
        action1.Position = 5

        let action2 = Action()
        action2.ID = "action-2"
        action2.Name = "Action 2"
        action2.Text = "Second"
        action2.Position = 5

        let action3 = Action()
        action3.ID = "action-3"
        action3.Name = "Action 3"
        action3.Text = "Third"
        action3.Position = 5

        try realm.write {
            realm.add(action1)
            realm.add(action2)
            realm.add(action3)
        }

        await sut.loadContent()

        #expect(sut.actions.count == 3)
        // All should have same position
        #expect(sut.actions.allSatisfy { $0.Position == 5 })
    }
}
