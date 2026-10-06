import Foundation

/// A step of Home Assistant's login flow (`POST /auth/login_flow` and `/auth/login_flow/<flow_id>`).
public struct LoginFlowStep: Decodable, Equatable {
    public enum Kind: Equatable {
        /// The server wants input: the fields in `dataSchema`, with `errors` from the last submission.
        case form
        /// Login succeeded; `result` holds the authorization code to exchange for a token.
        case createEntry
        /// The flow ended without logging in; `reason` says why.
        case abort
        case unknown(String)

        init(rawValue: String) {
            switch rawValue {
            case "form": self = .form
            case "create_entry": self = .createEntry
            case "abort": self = .abort
            default: self = .unknown(rawValue)
            }
        }
    }

    public let kind: Kind
    public let flowID: String
    public let stepID: String?
    public let dataSchema: [LoginFlowField]
    /// Field name (or `base` for the whole form) to error code, such as `invalid_auth`.
    public let errors: [String: String]
    public let result: String?
    public let reason: String?

    private enum CodingKeys: String, CodingKey {
        case type
        case flowID = "flow_id"
        case stepID = "step_id"
        case dataSchema = "data_schema"
        case errors
        case result
        case reason
    }

    public init(
        kind: Kind,
        flowID: String,
        stepID: String? = nil,
        dataSchema: [LoginFlowField] = [],
        errors: [String: String] = [:],
        result: String? = nil,
        reason: String? = nil
    ) {
        self.kind = kind
        self.flowID = flowID
        self.stepID = stepID
        self.dataSchema = dataSchema
        self.errors = errors
        self.result = result
        self.reason = reason
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.kind = try Kind(rawValue: container.decode(String.self, forKey: .type))
        self.flowID = try container.decode(String.self, forKey: .flowID)
        self.stepID = try container.decodeIfPresent(String.self, forKey: .stepID)
        self.dataSchema = try container.decodeIfPresent([LoginFlowField].self, forKey: .dataSchema) ?? []
        self.errors = try container.decodeIfPresent([String: String].self, forKey: .errors) ?? [:]
        self.result = try container.decodeIfPresent(String.self, forKey: .result)
        self.reason = try container.decodeIfPresent(String.self, forKey: .reason)
    }
}
