import Foundation
import ObjectMapper

public class Scene: Entity {
    @objc dynamic var entityIDs = [String]()
    @objc dynamic var backgroundColor: String?
    @objc dynamic var textColor: String?
    @objc dynamic var iconColor: String?

    public static let backgroundColorKey = "background_color"
    public static let textColorKey = "text_color"
    public static let iconColorKey = "icon_color"

    public override func mapping(map: Map) {
        super.mapping(map: map)
        entityIDs <- map["attributes.entity_id"]
        backgroundColor <- map["attributes." + Self.backgroundColorKey]
        textColor <- map["attributes." + Self.textColorKey]
        iconColor <- map["attributes." + Self.iconColorKey]
    }
}
