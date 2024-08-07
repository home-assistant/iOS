import AppIntents
import Foundation
import SwiftUI
import UIKit

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct ColorsAppEntity: AppEntity {
    var id: UUID
    var name: String
    var color: Color

    static var defaultQuery = ColorsQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            image: DisplayRepresentation.Image(systemName: "circle", tintColor: UIColor(color))
        )
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: "Color"
        )
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct ColorsQuery: EntityQuery {
    let sampleColors = [
        ColorsAppEntity(id: UUID(), name: "Red", color: .red),
        ColorsAppEntity(id: UUID(), name: "Green", color: .green),
        ColorsAppEntity(id: UUID(), name: "Blue", color: .blue),
    ]

    func entities(for identifiers: [UUID]) async throws -> [ColorsAppEntity] {
        sampleColors.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ColorsAppEntity] {
        sampleColors
    }
}
