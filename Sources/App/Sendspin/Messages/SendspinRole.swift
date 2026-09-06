import Foundation

/// The versioned role identifiers exchanged in `client/hello` and `server/activate`.
enum SendspinRole: String, Codable, Hashable {
    case player = "player@v1"
    case controller = "controller@v1"
    case metadata = "metadata@v1"
}
