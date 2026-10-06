import Foundation

/// An auth provider the server offers for logging in (`GET /auth/providers`), e.g. the built-in
/// "Home Assistant Local" username/password provider or trusted networks.
public struct LoginFlowProvider: Decodable, Equatable, Hashable {
    public let name: String
    /// Distinguishes several providers of the same type; `nil` for most setups.
    public let id: String?
    public let type: String

    public init(name: String, id: String?, type: String) {
        self.name = name
        self.id = id
        self.type = type
    }
}
