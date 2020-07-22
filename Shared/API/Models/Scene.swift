import Foundation
import ObjectMapper

public class Scene: Entity {
    @objc dynamic var entityIDs = [String]()

    public override func mapping(map: Map) {
        super.mapping(map: map)
        entityIDs <- map["attributes.entity_id"]
    }
}
