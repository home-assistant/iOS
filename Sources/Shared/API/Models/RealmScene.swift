import Foundation
import HAKit
import ObjectMapper
import RealmSwift

public final class RLMScene: Object, UpdatableModel {
    @objc public dynamic var identifier: String = ""
    @objc public dynamic var serverIdentifier: String = ""

    @objc private dynamic var backingPosition: Int = 0
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

    @objc private dynamic var backingActionEnabled: Bool = true
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

    @objc public dynamic var name: String?
    @objc public dynamic var icon: String?
    @objc public dynamic var backgroundColor: String?
    @objc public dynamic var textColor: String?
    @objc public dynamic var iconColor: String?

    public static func primaryKey(sourceIdentifier: String, serverIdentifier: String) -> String {
        #warning("multiserver - primary key duplication")
        return sourceIdentifier
    }

    override public class func primaryKey() -> String? {
        #keyPath(identifier)
    }

    static func serverIdentifierKey() -> String {
        #keyPath(serverIdentifier)
    }

    static func didUpdate(objects: [RLMScene], server: Server, realm: Realm) {
        let sorted = objects.sorted { lhs, rhs in
            let lhsText = lhs.name ?? lhs.identifier
            let rhsText = rhs.name ?? rhs.identifier
            return lhsText < rhsText
        }

        for (idx, object) in sorted.enumerated() {
            object.position = Action.PositionOffset.scene.rawValue + server.info.sortOrder + idx
        }
    }

    static func willDelete(objects: [RLMScene], server: Server?, realm: Realm) {
        // also delete our paired actions if they exist
        let actions = realm.objects(Action.self).filter("ID in %@", objects.map(\.identifier))
        Current.Log.info("deleting actions \(Array(actions.map(\.ID)))")
        realm.delete(actions)
    }

    func update(with entity: HAEntity, server: Server, using realm: Realm) -> Bool {
        precondition(entity.domain == "scene")

        if self.realm == nil {
            identifier = entity.entityId
        } else {
            precondition(identifier == entity.entityId)
        }

        serverIdentifier = server.identifier.rawValue
        name = entity.attributes.friendlyName
        icon = entity.attributes.icon ?? "mdi:palette"
        backgroundColor = entity.attributes["background_color"] as? String
        textColor = entity.attributes["text_color"] as? String
        iconColor = entity.attributes["icon_color"] as? String
        updateAction(realm: realm)

        return true
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
        action.serverIdentifier = serverIdentifier
        action.IconName = (icon ?? "mdi:alert").normalizingIconString
        action.Position = position
        action.Name = name ?? identifier
        action.Text = name ?? identifier

        if let backgroundColor = backgroundColor {
            action.BackgroundColor = backgroundColor
        }

        if let textColor = textColor {
            action.TextColor = textColor
        }

        if let iconColor = iconColor {
            action.IconColor = iconColor
        }

        // we indirectly reference this action, so we _must_ manually persist it
        action.Scene = self
        realm.add(action, update: .all)
    }
}
