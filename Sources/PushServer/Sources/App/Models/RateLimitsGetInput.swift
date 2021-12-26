import Vapor

struct RateLimitsGetInput: Content, Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("push_token", as: String.self, is: !.empty)
    }

    enum CodingKeys: String, CodingKey {
        case pushToken = "push_token"
    }

    var pushToken: String
}
