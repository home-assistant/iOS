import Foundation

public enum HAAPITransportMessage: Sendable, Equatable {
    case text(String)
    case data(Data)
}
