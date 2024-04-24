import Foundation

extension MaterialDesignIcons: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(unicode, forKey: .unicode)
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case unicode
    }
}
