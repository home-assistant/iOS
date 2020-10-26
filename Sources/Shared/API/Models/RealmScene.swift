import Foundation
import RealmSwift
import ObjectMapper

public final class RLMScene: Object, UpdatableModel {
    @objc dynamic private var underlyingSceneData: Data = Data()

    @objc dynamic public var identifier: String = ""

    @objc dynamic private var backingPosition: Int = 0
    public static var positionKeyPath: String { #keyPath(RLMScene.backingPosition) }
    public var position: Int {
        get {
            backingPosition
        }
        set {
            backingPosition = newValue
            actions.forEach { $0.Position = newValue }
        }
    }

    @objc dynamic private var backingActionEnabled: Bool = true
    public var actionEnabled: Bool {
        get {
            backingActionEnabled
        }
        set {
            precondition(realm?.isInWriteTransaction == true)
            guard let realm = realm else { return }
            backingActionEnabled = newValue
            updateAction(realm: realm)
        }
    }
    public let actions = LinkingObjects<Action>(fromType: Action.self, property: #keyPath(Action.Scene))
    public var scene: Scene {
        get {
            do {
                let object = try JSONSerialization.jsonObject(with: underlyingSceneData, options: [])
                return Mapper<Scene>().map(JSONObject: object)!
            } catch {
                fatalError("couldn't deserialize scene: \(underlyingSceneData)")
            }
        }
        set {
            do {
                underlyingSceneData = try JSONSerialization.data(withJSONObject: newValue.toJSON(), options: [])
            } catch {
                fatalError("couldn't serialize scene: \(scene)")
            }
        }
    }

    init(scene: Scene) {
        super.init()
        self.scene = scene
    }

    required override init() {
        super.init()
    }

    public override class func primaryKey() -> String? {
        #keyPath(identifier)
    }

    static func didUpdate(objects: [RLMScene], realm: Realm) {
        let sorted = objects.sorted { lhs, rhs in
            let lhsText = lhs.scene.FriendlyName ?? lhs.scene.ID
            let rhsText = rhs.scene.FriendlyName ?? rhs.scene.ID
            return lhsText < rhsText
        }

        for (idx, object) in sorted.enumerated() {
            object.position = Action.PositionOffset.scene.rawValue + idx
        }
    }

    static func willDelete(objects: [RLMScene], realm: Realm) {
        // also delete our paired actions if they exist
        let actions = realm.objects(Action.self).filter("ID in %@", objects.map(\.identifier))
        Current.Log.info("deleting actions \(Array(actions.map(\.ID)))")
        realm.delete(actions)
    }

    func update(with object: Scene, using realm: Realm) {
        if self.realm == nil {
            self.identifier = object.ID
        } else {
            precondition(identifier == object.ID)
        }

        if object.Icon == nil {
            object.Icon = "mdi:palette"
        }

        self.scene = object
        updateAction(realm: realm)
    }

    private func updateAction(realm: Realm) {
        guard actionEnabled else {
            for action in actions {
                realm.delete(action)
            }
            return
        }

        let action = actions.first ?? Action()
        if action.realm == nil {
            action.ID = identifier
            action.BackgroundColor = "#FFFFFF"
            action.TextColor = "#000000"
            action.IconColor = "#000000"
        } else {
            precondition(action.ID == identifier)
        }
        action.IconName = (scene.Icon ?? "mdi:alert").normalizingIconString
        action.Position = position
        action.Name = scene.FriendlyName ?? identifier
        action.Text = scene.FriendlyName ?? identifier

        if let backgroundColor = scene.backgroundColor {
            action.BackgroundColor = backgroundColor
        }

        if let textColor = scene.textColor {
            action.TextColor = textColor
        }

        if let iconColor = scene.iconColor {
            action.IconColor = iconColor
        }

        // we indirectly reference this action, so we _must_ manually persist it
        action.Scene = self
        realm.add(action, update: .all)
    }
}
