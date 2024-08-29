import AppIntents
import Foundation
import SFSafeSymbols

@available(iOS 16.4, macOS 13.0, watchOS 9.0, *)
struct SFSymbolEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Icon")

    static let defaultQuery = IntentSFSymbolAppEntityQuery()

    var id: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)", image: .init(systemName: id))
    }

    init(
        id: String
    ) {
        self.id = id
    }
}

@available(iOS 16.4, macOS 13.0, watchOS 9.0, *)
struct IntentSFSymbolAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SFSymbolEntity] {
        let allSymbols = SFSymbol.allSymbols.map(\.rawValue).map({ SFSymbolEntity(id: $0) })
        if identifiers.isEmpty {
            return allSymbols
        } else {
            return allSymbols.filter { identifiers.contains($0.id) }
        }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<SFSymbolEntity> {
        let allSymbols = SFSymbol.allSymbols.map(\.rawValue).map({ SFSymbolEntity(id: $0) })
            .filter { $0.id.contains(string) }
        return .init(items: allSymbols)
    }

    func suggestedEntities() async throws -> IntentItemCollection<SFSymbolEntity> {
        let allSymbols = SFSymbol.allSymbols.map(\.rawValue).map({ SFSymbolEntity(id: $0) })
        return .init(items: allSymbols)
    }
}
