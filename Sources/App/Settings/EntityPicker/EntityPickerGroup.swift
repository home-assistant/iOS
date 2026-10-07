import Foundation
import Shared

struct EntityPickerGroup: Identifiable {
    let title: String
    let entities: [HAAppEntity]

    var id: String { title }
}
