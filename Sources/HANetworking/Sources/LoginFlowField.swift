import Foundation

/// One input of a login-flow form step, as serialized from the step's `data_schema`.
public struct LoginFlowField: Decodable, Equatable {
    /// Key the value is submitted under, such as `username`, `password`, `code` (two-factor
    /// authentication) or `user` (trusted networks).
    public let name: String
    /// Schema type: `string`, `integer`, `boolean` or `select`.
    public let type: String
    public let isRequired: Bool
    /// Choices for a `select` field; empty otherwise.
    public let options: [LoginFlowFieldOption]

    private enum CodingKeys: String, CodingKey {
        case name
        case type
        case isRequired = "required"
        case options
    }

    public init(name: String, type: String, isRequired: Bool = true, options: [LoginFlowFieldOption] = []) {
        self.name = name
        self.type = type
        self.isRequired = isRequired
        self.options = options
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "string"
        self.isRequired = try container.decodeIfPresent(Bool.self, forKey: .isRequired) ?? false
        // Options of a non-`select` field (or a shape this client doesn't know) are not needed to log in.
        self.options = (try? container.decodeIfPresent([LoginFlowFieldOption].self, forKey: .options)) ?? []
    }
}
