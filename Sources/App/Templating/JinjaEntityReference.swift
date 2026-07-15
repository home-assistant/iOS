import Foundation

/// A known Home Assistant entity id found inside a Jinja string literal.
struct JinjaEntityReference: Equatable {
    let entityId: String
    let range: NSRange
    let name: String
    let subtitle: String?

    init(entityId: String, range: NSRange, name: String? = nil, subtitle: String? = nil) {
        self.entityId = entityId
        self.range = range
        self.name = name ?? entityId
        self.subtitle = subtitle
    }
}
