import Foundation
import ObjectMapper

public struct MobileAppConfigAction: ImmutableMappable, UpdatableModelSource {
    var name: String
    var backgroundColor: String?
    var labelText: String?
    var labelColor: String?
    var iconIcon: String?
    var iconColor: String?
    var showInCarPlay: Bool?
    var showInWatch: Bool?

    public init(map: Map) throws {
        self.name = try map.value("name")
        self.backgroundColor = try? map.value("background_color")
        self.labelText = try? map.value("label.text")
        self.labelColor = try? map.value("label.color")
        self.iconIcon = try? map.value("icon.icon")
        self.iconColor = try? map.value("icon.color")
        self.showInCarPlay = try? map.value("show_in_carplay")
        self.showInWatch = try? map.value("show_in_watch")
    }

    public var primaryKey: String { name }
}
