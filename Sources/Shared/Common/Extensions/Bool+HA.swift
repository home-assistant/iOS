import Foundation

public extension Bool? {
    var orFalse: Bool {
        self ?? false
    }
}
