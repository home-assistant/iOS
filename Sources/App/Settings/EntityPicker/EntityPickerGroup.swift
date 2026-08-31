import Foundation
import Shared

struct EntityPickerGroup: Identifiable {
    /// Distinct from the title: two devices can share a display name and still be separate sections.
    let id: String
    let title: String
    let entities: [HAAppEntity]

    init(id: String? = nil, title: String, entities: [HAAppEntity]) {
        self.id = id ?? title
        self.title = title
        self.entities = entities
    }
}
