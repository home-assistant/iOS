import Foundation

public extension Float? {
    var orZero: Float {
        self ?? 0
    }
}
