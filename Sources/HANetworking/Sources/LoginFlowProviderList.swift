import Foundation

/// `GET /auth/providers` response. Current servers wrap the list in an object next to
/// `preselect_remember_me`; older ones return the bare list.
struct LoginFlowProviderList: Decodable {
    let providers: [LoginFlowProvider]

    private enum CodingKeys: String, CodingKey {
        case providers
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            self.providers = try container.decode([LoginFlowProvider].self, forKey: .providers)
        } else {
            self.providers = try [LoginFlowProvider](from: decoder)
        }
    }
}
